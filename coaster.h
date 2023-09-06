/* Greg Bolsinga */
/* roller coaster */
/* April 28, 1992 */
/* cs319 Prof Hearn */

#ifndef _COASTER_
#define _COASTER_

#include "carnival.h"

#define JUMP 0.1      /* the 'size' of a track segment in the curves */
#define RADIUSOUT 8.0 /* the outer track radius */
#define RADIUSIN 7.0  /* the inner track radius */
#define LENGTH 40.0   /* the ground length of the flat part of the track */
#define SPEED1 10.392 /* multiplier for the falling part, to simulate speed */
#define SPEED2 5.555  /* multiplier for the flat part, to simulate speed */
#define PI acos(-1.0)

extern Coord rollerin[350][3];         /* Coords for the inner rail */
extern Coord rollerout[350][3];        /* Coords for the outer rail */

/* The following calculates the points of the coaster so that they 	*/
/* don't have to be calculated each time it is drawn.  It returns the	*/
/* number of points in the roller arrays.				*/

int getCoasterPts(void);

/* The following draws the struts of the roller coaster.	*/

void drawStrut(int i);

/* The following draws the roller coaster defined in the roller arrays */
/* Successive elements of the array are adjacent to each other on the  */
/* roller coaster.  This way, it can be easily drawn, as well as 	*/
/* making it easier to define the roller coaster rider's path in space. */

void coaster(int numpts); /* This is the number of pts in the roller arrays */

#endif /* _COASTER_ */
