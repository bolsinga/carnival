/* Greg Bolsinga */
/* roller coaster */
/* April 28, 1992 */
/* cs319 Prof Hearn */

#include "coaster.h"

/* The following calculates the points of the coaster so that they 	*/
/* don't have to be calculated each time it is drawn.  It returns the	*/
/* number of points in the roller arrays.				*/

int getCoasterPts()
{
    int i = 0;
    float a;
    float slope, b, theta, dy, dz, totalDist, maxy;

    maxy = (5.0*PI)/(RADIUSOUT/4.0);  /* the tallest the coaster gets */
    slope = maxy / LENGTH;	/* the slope of the falling part */
    b = 0.0 - slope * (-LENGTH); /* the 'y-intercept' of the falling pt */
    theta = atan(slope);	/* This is for calculating the line	*/
    dy = SPEED1 * JUMP * sin(theta); /* Change in y on falling pt	*/
    dz = SPEED1 * JUMP * cos(theta); /* Change in z on the falling pt	*/
    totalDist = fsqrt(LENGTH*LENGTH + maxy*maxy); /*length of falling pt*/

/* calculates points for the first part of the flat straightaway */

    for(a=-LENGTH / 2.0; a<= 0.0; a += SPEED2 * JUMP)
    {
	rollerout[i][0] = RADIUSOUT;
	rollerin[i][0] = RADIUSIN;
	rollerout[i][1] = rollerin[i][1] = 0.0;
	rollerout[i][2] = rollerin[i][2] = a;
	i++;
    }

/* calculates points for the climbing part */

    for(a=JUMP;a<=5*PI;a+=JUMP)
    {
	rollerout[i][0] = RADIUSOUT*cos(a);
	rollerin[i][0] = RADIUSIN*cos(a);
	rollerout[i][1] = rollerin[i][1] = a/(RADIUSOUT/4.0);
	rollerout[i][2] = RADIUSOUT*sin(a);
	rollerin[i][2] = RADIUSIN*sin(a);
	i++;
    }

/* calculates points for the downward slope straightaway */

    for(a=SPEED1*JUMP;a<=totalDist;a+=SPEED1 * JUMP)
    {
        rollerout[i][0] = -RADIUSOUT;
	rollerin[i][0] = -RADIUSIN;
        rollerout[i][1] = rollerout[i-1][1] - dy;
	rollerin[i][1] = rollerin[i-1][1] - dy;
        rollerout[i][2] = rollerout[i-1][2] - dz;
	rollerin[i][2] = rollerin[i-1][2] - dz;
	i++;
    }

/* calculates points for the flat half circle */

    for(a=JUMP;a<=PI;a+=JUMP)
    {
	rollerout[i][0] = RADIUSOUT*cos(a-PI);
        rollerin[i][0] = RADIUSIN*cos(a-PI);
	rollerout[i][1] = rollerin[i][1] = 0.0;
	rollerout[i][2] = RADIUSOUT*sin(a-PI) - LENGTH;
        rollerin[i][2] = RADIUSIN*sin(a-PI) - LENGTH;
	i++;
    }

/* calculates points for the last part of the flat straightaway */

    for(a= -LENGTH;a <= -LENGTH/2.0;a += SPEED2 * JUMP)
    {
	rollerout[i][0] = RADIUSOUT;
	rollerin[i][0] = RADIUSIN;
	rollerout[i][1] = rollerin[i][1] = 0.0;
	rollerout[i][2] = rollerin[i][2] = a;
	i++;
    }
    return i-1;
}

/* The following draws the struts of the roller coaster.	*/

void drawStrut(int i)
{
    char Strut = 1;
    int strut, height;
    Coord support[3];
    
    /* The following are struts which can't extend to the ground, */
    /* since they would intersect the roller coaster track.	  */

    if (i==93||i==157)
	strut = 155;
    else if (i==97||i==159)
	strut = 161;
    else if (i==193)
	strut = 191;
    else if (i==195)
	strut = 197;
    else strut = i;	/* These extend to the ground if they don't */
			/* intersect the track (see below)	    */

    if (strut != i)	/* attact strut about 2/3 the way up */
        height = 2.0 * rollerin[i][1] / 3.0;
    else if ((i<=33||i>=129)&&(i<=156||i>=161)&&(i<=192||i>=197)) 
	/* This makes sure that only the highest parts of the 	  */
	/* roller coaster track draw their struts.		  */
	height = -1.0;
    else Strut = 0;

    if (Strut)
	{
    	assignCoord(support, rollerin[strut]);
    	support[1] = height;
    	bgnline();
    	v3f(rollerin[i]);v3f(support);
    	endline();
    	assignCoord(support, rollerout[strut]);
	support[1] = height;
    	bgnline();
    	v3f(rollerout[i]);v3f(support);
    	endline();
	}
}

/* The following draws the roller coaster defined in the roller arrays */
/* Successive elements of the array are adjacent to each other on the  */
/* roller coaster.  This way, it can be easily drawn, as well as 	*/
/* making it easier to define the roller coaster rider's path in space. */

void coaster(int numpts) /* This is the number of pts in the roller arrays */
{
    int i, alternate = 0;
    short tracks[3] = {51, 51, 51};

    c3s(tracks);
    for(i=0;i<numpts;i++)
    {
	linewidth(3);
	bgnline();
	v3f(rollerin[i]);v3f(rollerin[i+1]);
	endline();
	bgnline();
	v3f(rollerout[i]);v3f(rollerout[i+1]);
	endline();
	linewidth(2);
	/* alternate the beams of the track so that motion is better */
	/* simulated.						     */
	if (alternate)
	    {
	    bgnline();
	    v3f(rollerin[i]);v3f(rollerout[i]);
	    endline();
	    drawStrut(i);
	    }
	alternate = !alternate;
    }
    linewidth(1);
}
