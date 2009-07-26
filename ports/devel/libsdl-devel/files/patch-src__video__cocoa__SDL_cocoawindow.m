--- src/video/cocoa/SDL_cocoawindow.m.orig	2009-07-17 11:45:41.000000000 -0700
+++ src/video/cocoa/SDL_cocoawindow.m	2009-07-17 11:45:57.000000000 -0700
@@ -167,6 +167,7 @@
     int button;
 
     index = _data->videodata->mouse;
+	printf("mouseDown %d\n", [theEvent buttonNumber]);
     switch ([theEvent buttonNumber]) {
     case 0:
         button = SDL_BUTTON_LEFT;
@@ -200,6 +201,7 @@
     int button;
 
     index = _data->videodata->mouse;
+	printf("mouseUp %d\n", [theEvent buttonNumber]);
     switch ([theEvent buttonNumber]) {
     case 0:
         button = SDL_BUTTON_LEFT;
