/* Greg Bolsinga */
/* carnival rides animation project */
/* April 28, 1992
/* cs319 */
/* Prof Hearn */

#ifndef _CARNIVAL_
#define _CARNIVAL_

/* SGI: compile using cc carnival.c -lgl_s -lm -o carnival */
/* Mac OS X: compile using */
/* ride the roller coaster by typing 'carnival -c'    */
/* ride the ferris wheel by typing 'carnival -w'      */
/* look around with 'carnival -l xl yl zl xa ya za'   */
/*   where (xl,yl,zl) is where you are, and           */
/*         (xa,ya,za) is where you are looking at.    */

/* #include <gl.h> */
#include <OpenGL/gl.h>
#include <OpenGL/glu.h>
#include <GLUT/glut.h>

#include <math.h>

typedef GLdouble Coord;

#define PI acos(-1.0)
#define PARTITIONS 64.0
#define INCREMENT PI / PARTITIONS
#define WHEELROT 0.04	/* angle the wheel will turn each time drawn */
#define TOUR 2*PI/WHEELROT  /* this in once around the ferris wheel  */ 
#define TRIPS 3		/* this sets how many times will ride the ride */

/* The following is a function that assigns one 3D coordinate to another. */

void assignCoord(Coord a[3], Coord b[3]);

/* The following calculates the average of two sets of 3D points. 	*/

void avgPts(Coord a[3], Coord b[3], Coord result[3]);

/* This draws some mountains, which are very simple, so the animation	*/
/* isn't slowed down.	*/

void mountains();

/* The folowing draws the entire scene. It takes the current rotation 	*/
/* of the ferris wheel and the number of points in the roller coaster	*/
/* arrays.  It returns the position of the ferris wheel rider.  	*/

void drawScene(Coord rotation, int rollPts, Coord fwv[3]);

#endif /* _CARNIVAL_ */
