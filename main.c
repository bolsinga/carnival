#include "carnival.h"
#include "coaster.h"
#include <stdlib.h>

static GLboolean gAnimating = GL_TRUE;

static void Init()
{

}

static void Display()
{

}

static void Idle()
{
	// Increment animation counters
}

static void SpecialKey(int key, int x, int y)
{
	// Rotate display in view mode
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
		
		// Handle riding ferris wheel
		
		// Handle riding roller coaster
	}
	glutPostRedisplay();
}

static void Visibility(int visible)
{
	glutIdleFunc(((visible == GLUT_VISIBLE) && gAnimating) ? Idle : NULL);
}

#ifdef USE_GLUT
int main(int argc, char** argv)
{
	glutInit(&argc, argv);
	glutInitWindowSize(640, 480);
	
	glutInitDisplayMode(GLUT_RGB | GLUT_DOUBLE | GLUT_DEPTH);
	
	glutCreateWindow("Carnival");
	
	Init();
	
	glutDisplayFunc(Display);
	glutSpecialFunc(SpecialKey);
	glutKeyboardFunc(Key);
	glutVisibilityFunc(Visibility);
	
	glutMainLoop();
	
	return 0;
}
#else
int main(int argc, char** argv)
{
	Coord xl, yl, zl, xa, ya, za;  /* these are the lookat points */
	Coord rotation = 0.0;	/* the rotation of the ferris wheel */
	Coord fwv[3] = {0.0, -6.0, 0.0 };	/* initial Ferris wheel view */
	Coord rider[3], nextrider[3];	/* points for the coaster rider */
	int i, j, rollPts, tilt = 0;
	char style = 0;
	
	if (argc <= 1)
	{
		printf("Come again!\n");
		style = 0;
	}
	else if (strcmp(argv[1],"-w") == 0)
	{
		printf("Ride the Ferris Wheel!\n");
		style = 1;
	}
	else if (strcmp(argv[1],"-c") == 0)
	{
		printf("Ride the Roller Coaster!\n");
		style = 2;
	}
	else if (strcmp(argv[1],"-l") == 0)
	{ 
		printf("Have a look around!\n");
		style = 3;
		xl = atoi(argv[2]);
		yl = atoi(argv[3]);
		zl = atoi(argv[4]);
		xa = atoi(argv[5]);
		ya = atoi(argv[6]);
		za = atoi(argv[7]);
	}
	
	if (style != 0)
	{
		rollPts = getCoasterPts();
		prefposition(0, 1265, 0, 983);
		winopen("carnival");
		RGBmode();
		doublebuffer();
		gconfig();
		glMatrixMode(GL_MODELVIEW);
		{
			GLint mm;
			glGetIntegerv(GL_MATRIX_MODE, &mm);
			glMatrixMode(GL_PROJECTION);
			glLoadIdentity();
			gluPerspective(0.1 * (600), 1265.0 / 983.0, 0.01, 150.0);
			glMatrixMode(mm);
		}
		glEnable(GL_DEPTH_TEST);
	}
	
	if (style == 1)
	{
		for(i = 1; i < TRIPS * TOUR; i++)
		{
			glLoadIdentity();
			lookat(fwv[0], fwv[1], fwv[2], fwv[0] + 1.0, fwv[1], fwv[2], 0);
			drawScene(rotation, rollPts, fwv);
			rotation -= WHEELROT;
			swapbuffers();
		}
	}
	else if (style == 2)
	{
		for(j = 1; j <= TRIPS; j++)
		{
			for(i = 0; i < rollPts; i++)
			{
				avgPts(rollerin[i], rollerout[i], rider);
				avgPts(rollerin[i+1], rollerout[i+1], nextrider);
				glLoadIdentity();
				/* These set the tilt of the roller coaster rider to simulate */
				/* the momentum.  They are just picked values.		      */
				if ((i >= 37 && i <= 56) || (i >= 174 && i <= 193) ||
					(i >= 233 && i <= 238) || (i >= 258 && i <= 263))
				{
					tilt = -15;
				}
				else if ((i >= 57 && i <= 173) || (i >= 239 && i <= 262))
				{
					tilt = -30;
				}
				else
				{
					tilt = 0;
				}
				
				lookat(rider[0], rider[1] + 0.5, rider[2], nextrider[0], nextrider[1] + 0.5, nextrider[2], tilt);
				drawScene(rotation, rollPts, fwv);
				rotation -= WHEELROT;
				swapbuffers();
			}
		}
	}
	else if (style == 3)
	{
		for(i = 1; i < TRIPS * TOUR; i++)
		{
			glLoadIdentity();
			lookat(xl, yl, zl, xa, ya, za, 0);
			drawScene(rotation, rollPts, fwv);
			rotation -= WHEELROT;
			swapbuffers();
		}
	}
	
	return 0;
}
#endif
