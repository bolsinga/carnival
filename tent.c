/* Greg Bolsinga */
/* Tent */
/* April 28, 1992 */
/* cs319 */
/* Prof Hearn */

#include "tent.h"

void tent()
{
	Coord v0[3] = {0.0,0.0,3.0};
	Coord v1[3] = {0.0,0.0,0.0};
	Coord v2[3] = {0.0,2.0,0.0};
	Coord v3[3] = {0.0,3.0,1.0};
	Coord v4[3] = {0.0,2.0,3.0};
	Coord v5[3] = {4.5,0.0,3.0};
	Coord v6[3] = {4.5,0.0,0.0};
	Coord v7[3] = {4.5,2.0,0.0};
	Coord v8[3] = {4.5,3.0,1.0};
	Coord v9[3] = {4.5,2.0,3.0};
	Coord v10[3] = {0.0,0.5,3.0};
	Coord v11[3] = {4.5,0.5,3.0};
	Coord v12[3] = {0.0,0.5,2.5};
	Coord v13[3] = {4.5,0.5,2.5};

	short dkgrey[3] = {110, 110, 110};
	short ltgrey[3] = {230, 230, 230};
	short blue[3] = {0, 0, 255};
	short ltblue[3] = {0, 0, 175};
	short red[3] = {255, 0, 0};
	short ltpink[3] = {255, 223, 227};

	Coord temp1[3],temp2[3],temp3[3],temp4[3],temp5[3],temp6[3];
	int i;
	float value, center;
	char colorIsRed = 1;

	/* Draw the sides */
	glBegin(GL_POLYGON);
	  glColor3sv(dkgrey);glVertex3fv(v0);
	  glColor3sv(ltgrey);glVertex3fv(v1);
	  glColor3sv(dkgrey);glVertex3fv(v2);glVertex3fv(v3);
	  glColor3sv(ltgrey);glVertex3fv(v4);
	glEnd();
	glBegin(GL_POLYGON);
	  glColor3sv(dkgrey);glVertex3fv(v5);
	  glColor3sv(ltgrey);glVertex3fv(v6);
	  glColor3sv(dkgrey);glVertex3fv(v7);glVertex3fv(v8);
	  glColor3sv(ltgrey);glVertex3fv(v9);
	glEnd();

	/* Draw the back */
	glBegin(GL_POLYGON);
	  glColor3sv(ltgrey);glVertex3fv(v1);
	  glColor3sv(dkgrey);glVertex3fv(v2);
	  glColor3sv(ltgrey);glVertex3fv(v7);
	  glColor3sv(dkgrey);glVertex3fv(v6);
	glEnd();

	/* Draw the front counter */
	glColor3sv(blue);
	glBegin(GL_POLYGON);
	glVertex3fv(v0);glVertex3fv(v10);glVertex3fv(v11);glVertex3fv(v5);
	glEnd();
	glColor3sv(ltblue);
	glBegin(GL_POLYGON);
	glVertex3fv(v10);glVertex3fv(v12);glVertex3fv(v13);glVertex3fv(v11);
	glEnd();

	/* Draw the awning */
	assignCoord(temp1, v4);
	assignCoord(temp2, v3);
	assignCoord(temp3, v2);
	value = 4.5 / 11.0;
	center = value / 2.0;
	for(i=1;i<=11;i++)
	  {
	  assignCoord(temp6, temp1);
	  assignCoord(temp5, temp2);
	  assignCoord(temp4, temp3);
	  temp6[0] += value;
	  temp5[0] += value;
	  temp4[0] += value;
	  if (colorIsRed)
		glColor3sv(red);
	  else glColor3sv(ltpink);
	  glBegin(GL_POLYGON);
	  glVertex3fv(temp1);glVertex3fv(temp2);glVertex3fv(temp5);glVertex3fv(temp6);
	  glEnd();
	  glBegin(GL_POLYGON);
	  glVertex3fv(temp2);glVertex3fv(temp3);glVertex3fv(temp4);glVertex3fv(temp5);
	  glEnd();
	  glPushMatrix();
	  glTranslatef(0,0,3.0);
	  { GLUquadricObj *qobj = gluNewQuadric(); glPushMatrix(); glTranslatef(center, 2.0, 0.); gluPartialDisk( qobj, 0., temp6[0]-center, 32, 1, (1800)*.1, ((0)-(1800))*.1); glPopMatrix(); gluDeleteQuadric(qobj); }
	  glPopMatrix();
	  assignCoord(temp1, temp6);
	  assignCoord(temp2, temp5);
	  assignCoord(temp3, temp4);
	  colorIsRed = !colorIsRed;
	  center += value;
	  }
}
