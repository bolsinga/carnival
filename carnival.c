/* Greg Bolsinga */
/* carnival rides animation project */
/* April 28, 1992 */
/* cs319 */
/* Prof Hearn */

/* SGI: compile using cc carnival.c -lgl_s -lm -o carnival */
/* Mac OS X: compile using cc -Wall *.c -framework OpenGL -framework GLUT -lobjc -o carnival */
/* ride the roller coaster by typing 'carnival -c'    */
/* ride the ferris wheel by typing 'carnival -w'      */
/* look around with 'carnival -l xl yl zl xa ya za'   */
/*   where (xl,yl,zl) is where you are, and           */
/*         (xa,ya,za) is where you are looking at.    */

#include "carnival.h"
#include "tent.h"
#include "ferris.h"
#include "coaster.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

Coord rollerin[350][3];         /* Coords for the inner rail */
Coord rollerout[350][3];        /* Coords for the outer rail */

/* The following is a function that assigns one 3D coordinate to another. */

void assignCoord(Coord a[3], Coord b[3])
{
	int i;
	for(i = 0; i < 3; i++)
	{
		a[i] = b[i];
	}
}

/* The following calculates the average of two sets of 3D points. 	*/

void avgPts(Coord a[3], Coord b[3], Coord result[3])
{
	int i;
	for(i = 0; i < 3; i++)
	{
		result[i] = (a[i] + b[i]) / 2.0;
	}
}

/* This draws some mountains, which are very simple, so the animation	*/
/* isn't slowed down.	*/

void mountains()
{
	Coord mnt1p[3] = {80, 50, 0 };
	Coord mnt1b1[3] = {80, -1.0, -50 };
	Coord mnt1b2[3] = {80, -1.0, 50 };
	Coord mnt2p[3] = {75, 40, -20 };
	Coord mnt2b1[3] = {75, -1.0, -40 };
	Coord mnt2b2[3] = {75, -1.0, 0.0 };
	Coord mnt3p[3] = {85, 45, -45 };
	Coord mnt3b1[3] = {85, -1, -70 };
	Coord mnt3b2[3] = {85, -1, -5 };
	
	GLubyte brown[3] = {116, 87, 11 };
	GLubyte snow[3] = {196, 196, 196 };
	
	glBegin(GL_POLYGON);
		glColor3ubv(brown);
			glVertex3fv(mnt1b1);
			glVertex3fv(mnt1b2);
		glColor3ubv(snow);
			glVertex3fv(mnt1p);
	glEnd();
	
	glBegin(GL_POLYGON);
		glColor3ubv(brown);
			glVertex3fv(mnt2b1);
			glVertex3fv(mnt2b2);
		glColor3ubv(snow);
			glVertex3fv(mnt2p);
	glEnd();
	
	glBegin(GL_POLYGON);
		glColor3ubv(brown);
			glVertex3fv(mnt3b1);
			glVertex3fv(mnt3b2);
		glColor3ubv(snow);
			glVertex3fv(mnt3p);
	glEnd();
}

/* The folowing draws the entire scene. It takes the current rotation 	*/
/* of the ferris wheel and the number of points in the roller coaster	*/
/* arrays.  It returns the position of the ferris wheel rider.  	*/

void drawScene(Coord rotation, int rollPts, Coord fwv[3])
{
	Coord gr1[3] = {100, -1.0, 100 };
	Coord gr2[3] = {100, -1.0, -100 };
	Coord gr3[3] = {-100, -1.0, -100 };
	Coord gr4[3] = {-100, -1.0, 100 };
	
	GLubyte grass[3] = {123, 193, 87 };
	GLubyte sky[3] = {85, 172, 255 };

#ifndef USE_GLUT	
	glColor3ubv(sky);
	clear();
	glClearDepth(1.);
	glClear(GL_DEPTH_BUFFER_BIT);
#endif
	
	/* Draw the ground */
	glColor3ubv(grass);
	glBegin(GL_POLYGON);
		glVertex3fv(gr1);
		glVertex3fv(gr2);
		glVertex3fv(gr3);
		glVertex3fv(gr4);
	glEnd();
	
	/* Draw some mountains */
	mountains();
	
	coaster(rollPts);
	
	glPushMatrix();
		glTranslatef(-25.0, 6.5, 0.0);
		ferris(rotation, fwv);
		fwv[0] += -25.0;
		fwv[1] += 6.5;
	glPopMatrix();
	
	glPushMatrix();
		glTranslatef(17, -1.0, -8);
		glRotatef(0.1 * (-900), 0, 1, 0);
		tent();
	glPopMatrix();
	
	glPushMatrix();
		glTranslatef(-22, -1, -11);
		tent();
	glPopMatrix();
	
	/*
	for(i=0; i<100000; i++);
	*/
	
	/* return the position of the ferris wheel rider */
}
