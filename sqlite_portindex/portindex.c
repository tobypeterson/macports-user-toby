#include <sys/param.h>
#include <assert.h>
#include <dirent.h>
#include <err.h>
#include <getopt.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>

#include <sqlite3.h>
#include <tcl.h>

typedef void (*mport_traverse_callback)(const char *, void *);

void mport_traverse(char *, void *, mport_traverse_callback);

struct index_context {
	char *directory;
	Tcl_Interp *interp;
	sqlite3 *db;
	sqlite3_stmt *stmt;
#ifdef LEGACY_PORTINDEX
	int fd;
#endif /* LEGACY_PORTINDEX */
};

static struct index_context *index_context_init(char *directory);
static void index_context_cleanup(struct index_context *ictx);
static void usage(void);

static void
warndb(sqlite3 *db, char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);

	fprintf(stderr, ": %s\n", sqlite3_errmsg(db));
}

void
mport_traverse(char *root, void *context, mport_traverse_callback callback)
{
	DIR *dir1, *dir2;
	struct dirent *entry1, *entry2;
	char *catpath, *portdir;

	dir1 = opendir(root);
	while ((entry1 = readdir(dir1)) != NULL) {
		if (!(entry1->d_type & DT_DIR) || entry1->d_name[0] == '.' || entry1->d_name[0] == '_') {
			continue;
		}
		asprintf(&catpath, "%s/%s", root, entry1->d_name);
		dir2 = opendir(catpath);
		free(catpath);
		while ((entry2 = readdir(dir2)) != NULL) {
			if (!(entry2->d_type & DT_DIR) || entry2->d_name[0] == '.') {
				continue;
			}
			asprintf(&portdir, "%s/%s", entry1->d_name, entry2->d_name);
			callback(portdir, context);
			free(portdir);
		}
		closedir(dir2);
	}
	closedir(dir1);
}

static void
insert_info(Tcl_Obj *info, struct index_context *ictx)
{
	int status, i, objc;
	Tcl_Obj **objv;
	char *col, *val;
	int bind_index;

	sqlite3_reset(ictx->stmt);

	// xxx: put into db blah
	status = Tcl_ListObjGetElements(ictx->interp, info, &objc, &objv);
	assert(status == TCL_OK);
	assert((objc % 2) == 0);

	for (i = 0; i < objc; i += 2) {
		asprintf(&col, "@%s", Tcl_GetString(objv[i]));
		bind_index = sqlite3_bind_parameter_index(ictx->stmt, col);
		if (bind_index > 0) {
			val = Tcl_GetString(objv[i + 1]);
			status = sqlite3_bind_text(ictx->stmt, bind_index, val, -1, SQLITE_TRANSIENT);
			if (status != SQLITE_OK) {
				warndb(ictx->db, "sqlite3_bind_text");
			}
		}
		free(col);
	}

	status = sqlite3_step(ictx->stmt);
	assert(status == SQLITE_DONE);

#ifdef LEGACY_PORTINDEX
	// write to file
#endif /* LEGACY_PORTINDEX */
}

static void
pindex(const char *portdir, void *ctx)
{
	struct index_context *ictx = (struct index_context *)ctx;
	char *url;
	Tcl_Obj *eobjv[2];
	Tcl_Obj *port;
	Tcl_Obj *info;

	// set port [mportopen $url]
	eobjv[0] = Tcl_NewStringObj("mportopen", -1);
	asprintf(&url, "file://%s/%s", ictx->directory, portdir);
	eobjv[1] = Tcl_NewStringObj(url, -1);
	free(url);
	Tcl_EvalObjv(ictx->interp, 2, eobjv, 0);
	port = Tcl_GetObjResult(ictx->interp);

	// set info [mportinfo $port]
	eobjv[0] = Tcl_NewStringObj("mportinfo", -1);
	eobjv[1] = port;
	Tcl_EvalObjv(ictx->interp, 2, eobjv, 0);
	info = Tcl_GetObjResult(ictx->interp);

	insert_info(info, ictx);

	// mportclose $port
	eobjv[0] = Tcl_NewStringObj("mportclose", -1);
	eobjv[1] = port;
	Tcl_EvalObjv(ictx->interp, 2, eobjv, 0);
}

int
main(int argc, char *argv[])
{
	int ch;
	char directory[MAXPATHLEN];
	struct index_context *ictx;

	while ((ch = getopt(argc, argv, "")) != -1) {
		switch (ch) {
		default:
			usage();
		}
	}

	argc -= optind;
	argv += optind;

	switch (argc) {
	case 1:
		strlcpy(directory, argv[0], sizeof(directory));
		break;
	case 0:
		if (getcwd(directory, sizeof(directory)) == NULL) {
			err(1, "getcwd");
		}
		break;
	default:
		usage();
	}

	ictx = index_context_init(directory);
	if (ictx == NULL) {
		exit(1);
	}

	/* Traverse the directory tree, indexing each port. */
	mport_traverse(directory, ictx, pindex);

	index_context_cleanup(ictx);

	return 0;
}

static int
callback_select(void *ctx __unused, int count, char **values, char **keys)
{
	int i;

	for (i = 0; i < count; i++) {
		printf("%s : %s\n", keys[i], values[i]);
	}

	return 0;
}

static void
create_table(sqlite3 *db)
{
	int rc;

	rc = sqlite3_exec(db, "CREATE TABLE portindex ("
		"categories,"
		"depends_build,"
		"depends_lib,"
		"depends_run,"
		"description,"
		"epoch,"
		"homepage,"
		"long_description,"
		"maintainers,"
		"name,"
		"platforms,"
		"portdir,"
		"revision,"
		"variants,"
		"version"
		")", NULL, NULL, NULL);
	if (rc != SQLITE_OK) {
		warndb(db, "sqlite3_exec");
	}
}

static void
create_stmt(struct index_context *ictx)
{
	int status;

	status = sqlite3_prepare_v2(ictx->db, "INSERT INTO portindex VALUES ("
		"@categories,"
		"@depends_build,"
		"@depends_lib,"
		"@depends_run,"
		"@description,"
		"@epoch,"
		"@homepage,"
		"@long_description,"
		"@maintainers,"
		"@name,"
		"@platforms,"
		"@portdir,"
		"@revision,"
		"@variants,"
		"@version"
		")", -1, &ictx->stmt, NULL);
	if (status != SQLITE_OK) {
		warndb(ictx->db, "sqlite3_prepare_v2");
	}
}

static struct index_context *
index_context_init(char *directory)
{
	struct index_context *ictx;
	int status;

	ictx = calloc(1, sizeof(struct index_context));

	ictx->directory = strdup(directory);

	// XXX: generate temp file...
	status = sqlite3_open("PortIndex.db", &ictx->db);
	if (status != SQLITE_OK) {
		warndb(ictx->db, "sqlite3_open");
	}

	create_table(ictx->db);
	create_stmt(ictx);

#ifdef LEGACY_PORTINDEX
	// open portindex
#endif /* LEGACY_PORTINDEX */

	ictx->interp = Tcl_CreateInterp();
	Tcl_Init(ictx->interp);
	Tcl_EvalFile(ictx->interp, "/Library/Tcl/macports1.0/macports_fastload.tcl");
	Tcl_PkgRequire(ictx->interp, "macports", "1.0", 0);
	Tcl_Eval(ictx->interp, "mportinit");

	return ictx;
}

static void
index_context_cleanup(struct index_context *ictx)
{
	int status;

	Tcl_DeleteInterp(ictx->interp);
	ictx->interp = NULL;

#ifdef LEGACY_PORTINDEX
	// close portindex
#endif /* LEGACY_PORTINDEX */

	// XXX: debugging
	status = sqlite3_exec(ictx->db, "SELECT * FROM portindex", callback_select, NULL, NULL);
	if (status != SQLITE_OK) {
		warndb(ictx->db, "sqlite3_exec");
	}

	status = sqlite3_finalize(ictx->stmt);
	if (status != SQLITE_OK) {
		warndb(ictx->db, "sqlite3_finalize");
	}

	status = sqlite3_close(ictx->db);
	if (status != SQLITE_OK) {
		warndb(ictx->db, "sqlite3_close");
	}

	free(ictx->directory);
	ictx->directory = NULL;

	free(ictx);
}

static void
usage(void)
{
	fprintf(stderr, "usage: portindex [directory]\n");
	exit(1);
}
