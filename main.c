#include "carnival.h"
#include "coaster.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/*
	GL documentation: <http://publibn.boulder.ibm.com/doc_link/en_US/a_doc_lib/libs/gl32tref/gl32tref02.htm#ToC>
	OpenGL Documentation: <http://www.cevis.uni-bremen.de/~uwe/opengl/opengl.html>
		<http://www.opengl.org/developers/documentation/Specs/glspec1.1/glspec.html>
*/

#define ALLOW_LOOKAROUND

typedef enum {
	View_Coaster,
	View_Ferris,
	View_Point
} View_Style;

static GLboolean gAnimating = GL_TRUE;
static View_Style gStyle = View_Coaster;

static Coord gRotation = 0.0;	/* the rotation of the ferris wheel */
static int gRollPts;
static int gCurrentCoaster = 0;
static Coord gFWV[3] = {0.0, -6.0, 0.0 };	/* initial Ferris wheel view */

static GLdouble geyex, geyey, geyez, gcenterx, gcentery, gcenterz, gupx, gupy, gupz;

static GLint gThreshhold = 750;
static GLint gCurrentIteration = 0;

static GLdouble gStep = 0.1;

static void dump()
{
	fprintf(stderr, "gAnimating: %d gStyle: %d gRollPts: %d gCurrentCoaster: %d gRotation: %f\n", gAnimating, gStyle, gRollPts, gCurrentCoaster, gRotation);
	fprintf(stderr, "Ferris View: (%f, %f, %f)\n", gFWV[0], gFWV[1], gFWV[2]);
	fprintf(stderr, "LookAt: eye (%f, %f, %f) center (%f, %f, %f) up (%f, %f, %f)\n", geyex, geyey, geyez, gcenterx, gcentery, gcenterz, gupx, gupy, gupz);
	fprintf(stderr, "**********\n");
}

static void Init()
{
	gRollPts = getCoasterPts();

	glClearColor(0.33, 0.67, 1.0, 1.0);
	glEnable(GL_DEPTH_TEST);
}

static void Display()
{
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	glPushMatrix();
		gluLookAt(geyex, geyey, geyez, gcenterx, gcentery, gcenterz, gupx, gupy, gupz);
		
		drawScene(gRotation, gRollPts, gFWV);
	glPopMatrix();
	
	glutSwapBuffers();
}

static void Idle()
{
	if (++gCurrentIteration < gThreshhold)
	{
		return;
	}
	gCurrentIteration = 0;
	
	Coord rider[3], nextrider[3];	/* points for the coaster rider */
	int tilt;
	
	switch (gStyle)
	{
		case View_Coaster:			
			if (gCurrentCoaster > gRollPts - 1)
			{
				gCurrentCoaster = 0;
			}

			avgPts(rollerin[gCurrentCoaster], rollerout[gCurrentCoaster], rider);
			avgPts(rollerin[gCurrentCoaster + 1], rollerout[gCurrentCoaster + 1], nextrider);

			/* These set the tilt of the roller coaster rider to simulate */
			/* the momentum.  They are just picked values.		      */
			if ((gCurrentCoaster >= 37 && gCurrentCoaster <= 56) || (gCurrentCoaster >= 174 && gCurrentCoaster <= 193) ||
				(gCurrentCoaster >= 233 && gCurrentCoaster <= 238) || (gCurrentCoaster >= 258 && gCurrentCoaster <= 263))
			{
				tilt = -15;
			}
			else if ((gCurrentCoaster >= 57 && gCurrentCoaster <= 173) || (gCurrentCoaster >= 239 && gCurrentCoaster <= 262))
			{
				tilt = -30;
			}
			else
			{
				tilt = 0;
			}

			geyex = rider[0];
			geyey = rider[1] + 0.5;
			geyez = rider[2];
			gcenterx = nextrider[0];
			gcentery = nextrider[1] + 0.5;
			gcenterz = nextrider[2];
			gupx = 0.0;
			gupy = 1.0;
			gupz = 0.0;
			
//			dump();
			break;
			
		case View_Ferris:
			geyex = gFWV[0];
			geyey = gFWV[1];
			geyez = gFWV[2];
			gcenterx = gFWV[0] + 1.0;
			gcentery = gFWV[1];
			gcenterz = gFWV[2];
			gupx = 0.0;
			gupy = 1.0;
			gupz = 0.0;
			break;
			
		case View_Point:
		/*
			geyex = 0;
			geyey = 0;
			geyez = 0;
			gcenterx = 0;
			gcentery = 0;
			gcenterz = 0;
			gupx = 0.0;
			gupy = 1.0;
			gupz = 0.0;
		*/
			break;
	}
	
	glutPostRedisplay();

	// Increment animation counters
	gRotation -= WHEELROT;
	gCurrentCoaster++;
}

static void SpecialKey(int key, int x, int y)
{
	if (gStyle == View_Point)
	{
		// Rotate display in view mode
		switch (key) {
			case GLUT_KEY_UP:
				geyey += gStep;
				break;
			case GLUT_KEY_DOWN:
				geyey -= gStep;
				break;
			case GLUT_KEY_LEFT:
				geyex -= gStep;
				break;
			case GLUT_KEY_RIGHT:
				geyex += gStep;
				break;
		}
		glutPostRedisplay();
	}
}

static void Key(unsigned char key, int x, int y)
{
	switch (key) {
		case 27:
			exit(0);
			break;
		case ' ':
			gAnimating = !gAnimating;
			glutIdleFunc(gAnimating ? Idle : NULL);
		break;
		case 't':
			if (gStyle != View_Point)
			{
				// Toggle between Coaster & Ferris
				gStyle = (gStyle == View_Coaster) ? View_Ferris : View_Coaster;
			}
			break;
#ifdef ALLOW_LOOKAROUND
		case 's':
			gStyle = (gStyle == View_Point) ? View_Coaster : View_Point;
			break;
#endif
		case 'z':
			if (gStyle == View_Point)
			{
				geyez -= gStep;
			}
			break;
		case 'x':
			if (gStyle == View_Point)
			{
				geyez += gStep;
			}
			break;
	}
	glutPostRedisplay();
}

static void Visibility(int visible)
{
	glutIdleFunc(((visible == GLUT_VISIBLE) && gAnimating) ? Idle : NULL);
}

static void Reshape(int width, int height)
{
	glViewport(0, 0, width, height);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluPerspective(0.1 * (600), (float)(width / height), 0.01, 150.0);
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
}

int main(int argc, char** argv)
{
	glutInit(&argc, argv);
	glutInitWindowSize(640, 480);
	
	glutInitDisplayMode(GLUT_RGB | GLUT_DOUBLE | GLUT_DEPTH);
	
	glutCreateWindow("carnival");
	
	Init();
	
	glutDisplayFunc(Display);
	glutSpecialFunc(SpecialKey);
	glutKeyboardFunc(Key);
	glutVisibilityFunc(Visibility);
	glutReshapeFunc(Reshape);
	
	glutMainLoop();
	
	return 0;
}
