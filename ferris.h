/* Greg Bolsinga */
/* Ferris Wheel */
/* April 28, 1992 */
/* cs319  Prof Hearn */

#ifndef _FERRIS_
#define _FERRIS_

#include "carnival.h"

#define PI acos(-1.0)
#define SPOKE PI / 4.0  /* position of the spokes in radians */

/* The following draws the ferris wheel carriage. It gets the points */
/* of the spokes on both sides, and draws it right in the middle.    */

void carriage(Coord wheel1[3], Coord wheel2[3]);
	
/* The following draws the ferris wheel and returns the position of the */
/* rider, who initially starts off at the bottom at 6*PI/4 radians	*/
/* It recieves the current angle of rotation.  This way the wheel 	*/
/* rotates when the angle changes.					*/

void ferris(Coord angle, Coord* position);

#endif /* _FERRIS_ */
