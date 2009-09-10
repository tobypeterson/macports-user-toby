typedef struct mp_port_s *mp_port_t;

mp_port_t mp_port_create(CFURLRef url, CFDictionaryRef options);
void mp_port_destroy(mp_port_t port);
CFStringRef mp_port_variable(mp_port_t port, CFStringRef var);
CFArrayRef mp_port_defined_variants(mp_port_t port);
CFArrayRef mp_port_defined_platforms(mp_port_t port);
