/* Greg Bolsinga */
/* Ferris Wheel */
/* April 28, 1992 */
/* cs319  Prof Hearn */

#include "ferris.h"

/* The following draws the ferris wheel carriage. It gets the points */
/* of the spokes on both sides, and draws it right in the middle.    */

void carriage(Coord wheel1[3], Coord wheel2[3])
{
	Coord v1[3], v2[3], v3[3], v4[3], v5[3], v6[3];
	Coord v7[3], v8[3], v9[3], v10[3], v11[3], v12[3];
	Coord side1[3], side2[3];
	
	GLubyte dkgrey[3] = {76, 66, 102 };
	GLubyte dkrgrey[3] = {40, 40, 40 };
	GLubyte blue[3] = {66, 66, 230 };
	GLubyte steel[3] = {65, 74, 82 };
	
	/* The following sets up all the proper coordinates. */
	
	assignCoord(side1, wheel1);
	assignCoord(side2, wheel2);
	side1[2] = 1.25;
	side2[2] = -1.25;
	assignCoord(v1, side1);
	assignCoord(v2, side2);
	assignCoord(v3, side2);
	assignCoord(v4, side1);
	assignCoord(v5, side1);
	assignCoord(v6, side2);
	assignCoord(v7, side1);
	assignCoord(v8, side2);
	assignCoord(v9, side1);
	assignCoord(v10, side2);
	assignCoord(v11, side1);
	assignCoord(v12, side2);
	v1[0] = v2[0] = v3[0] = v4[0] = v5[0] = v6[0] -= 0.5;
	v7[0] = v8[0] = v9[0] = v10[0] = v11[0] = v12[0] += 0.25;
	v1[1] = v2[1] += 0.5;
	v5[1] = v6[1] = v7[1] = v8[1] += 0.25;
	v3[1] = v4[1] = v9[1] = v10[1] -= 0.5;
	v11[1] = v12[1] -= 0.7;
	
	glColor3ubv(dkgrey);
	glBegin(GL_POLYGON); /* back of chair */
		glVertex3fv(v1);
		glVertex3fv(v2);
		glVertex3fv(v3);
		glVertex3fv(v4);
	glEnd();
	
	glColor3ubv(dkrgrey);
	glBegin(GL_POLYGON); /* seat of chair */
		glVertex3fv(v4);
		glVertex3fv(v3);
		glVertex3fv(v10);
		glVertex3fv(v9);
	glEnd();
	
	glColor3ubv(dkgrey);
	glBegin(GL_POLYGON); /* foot part */
		glVertex3fv(v11);
		glVertex3fv(v12);
		glVertex3fv(v10);
		glVertex3fv(v9);
	glEnd();
	
	glColor3ubv(blue);
	glBegin(GL_POLYGON); /*one side*/
		glVertex3fv(v4);
		glVertex3fv(v5);
		glVertex3fv(v7);
		glVertex3fv(v9);
	glEnd();
	
	glBegin(GL_POLYGON); /*other side*/
		glVertex3fv(v3);
		glVertex3fv(v6);
		glVertex3fv(v8);
		glVertex3fv(v10);
	glEnd();
	
	glColor3ubv(steel);
	glBegin(GL_LINE_STRIP); /*draw axels */
		glVertex3fv(side1);
		glVertex3fv(wheel1);
	glEnd();
	
	glBegin(GL_LINE_STRIP);
		glVertex3fv(side2);
		glVertex3fv(wheel2);
	glEnd();
}

/* The following draws the ferris wheel and returns the position of the */
/* rider, who initially starts off at the bottom at 6*PI/4 radians	*/
/* It recieves the current angle of rotation.  This way the wheel 	*/
/* rotates when the angle changes.					*/

void ferris(Coord angle, Coord* sight)
{
	int i;
	Coord bottom; /* the angle of the 'bottom' spoke */
	Coord center1[3] = {0.0, 0.0, 1.5 };
	Coord center2[3] = {0.0, 0.0, -1.5 };
	Coord axel1[3] = {0.0, 0.0, 2.5 };
	Coord axel2[3] = {0.0, 0.0, -2.5 };
	Coord b1[3] = {-4.5, -7.0, 3.0 };
	Coord b2[3] = {4.5, -7.0, 3.0 };
	Coord b3[3] = {4.5, -7.0, -3.0 };
	Coord b4[3] = {-4.5, -7.0, -3.0 };
	Coord temp1[8][3], temp2[8][3];
	
	GLubyte yellow[3] = {255, 255, 40 };
	GLubyte steel[3] = {65, 74, 82 };
	
	glLineWidth(2);
	glColor3ubv(yellow);
	glPushMatrix();
		glTranslatef(0.0, 0.0, -1.5);
		{
			GLUquadricObj *qobj = gluNewQuadric();
			gluQuadricDrawStyle(qobj, GLU_SILHOUETTE);
			glPushMatrix();
				glTranslatef(0.0, 0.0, 0.);
				gluDisk(qobj, 0.0, 6.0, 32, 1);
			glPopMatrix();
			gluDeleteQuadric(qobj);
		}
	glPopMatrix();
	glPushMatrix();
		glTranslatef(0.0, 0.0, 1.5);
		{
			GLUquadricObj *qobj = gluNewQuadric();
			gluQuadricDrawStyle(qobj, GLU_SILHOUETTE);
			glPushMatrix();
				glTranslatef(0.0, 0.0, 0.);
				gluDisk(qobj, 0.0, 6.0, 32, 1);
			glPopMatrix();
			gluDeleteQuadric(qobj);
		}
	glPopMatrix();
	for(i = 0; i <= 7; i++)
	{
		if (i == 6)
		{
			/* this is the rider position */
			bottom = angle;
		}
		temp1[i][0] = 6.0 * cos(angle);
		temp1[i][1] = 6.0 * sin(angle);
		temp1[i][2] = 1.5;
		assignCoord(temp2[i], temp1[i]);
		temp2[i][2] = -1.5;
		
		glBegin(GL_LINE_STRIP);
			glVertex3fv(temp1[i]);
			glVertex3fv(center1);
		glEnd();
		
		glBegin(GL_LINE_STRIP);
			glVertex3fv(temp2[i]);
			glVertex3fv(center2);
		glEnd();
		
		carriage(temp1[i], temp2[i]);
		glColor3ubv(yellow);
		angle += SPOKE;
	}
	
	glColor3ubv(steel);
	glLineWidth(4);
	glBegin(GL_LINE_STRIP);
		glVertex3fv(axel1);
		glVertex3fv(axel2);
	glEnd();
	
	glBegin(GL_LINE_STRIP);
		glVertex3fv(b1);
		glVertex3fv(axel1);
		glVertex3fv(b2);
	glEnd();
	
	glBegin(GL_LINE_STRIP);
		glVertex3fv(b3);
		glVertex3fv(axel2);
		glVertex3fv(b4);
	glEnd();
	
	sight[0] = 6.0 * cos(bottom - 0.1);
	sight[1] = 6.0 * sin(bottom - 0.1) + 0.5;
	sight[2] = 0.0;
	
	glLineWidth(1);
	/* Returns position of 'bottom' spoke of the next */
	/* iteration (angle - 0.1 is the next iteration) */
}
