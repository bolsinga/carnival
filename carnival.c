/* Greg Bolsinga */
/* carnival rides animation project */
/* April 28, 1992
/* cs319 */
/* Prof Hearn */

/* compile using cc carnival.c -lgl_s -lm -o carnival */
/* ride the roller coaster by typing 'carnival -c'    */
/* ride the ferris wheel by typing 'carnival -w'      */
/* look around with 'carnival -l xl yl zl xa ya za'   */
/*   where (xl,yl,zl) is where you are, and           */
/*         (xa,ya,za) is where you are looking at.    */

#include <gl.h>
#include <math.h>
#include <device.h>
#include "tent.h"
#include "ferris.h"
#include "coaster.h"

#define PI acos(-1.0)
#define PARTITIONS 64.0
#define INCREMENT PI / PARTITIONS
#define WHEELROT 0.04	/* angle the wheel will turn each time drawn */
#define TOUR 2*PI/WHEELROT  /* this in once around the ferris wheel  */ 
#define TRIPS 3		/* this sets how many times will ride the ride */

Matrix ID = {
	{1,0,0,0},
	{0,1,0,0},
	{0,0,1,0},
	{0,0,0,1}};

/* The following is a function that assigns one 3D coordinate to another. */

void assignCoord(a, b)
Coord a[3], b[3];
{
	int i;
	for(i=0;i<3;i++)
	  a[i] = b[i];
}

/* The following calculates the average of two sets of 3D points. 	*/

Coord* avgPts(a, b)
Coord a[3], b[3];
{
	int i;
	Coord average[3];

	for(i=0;i<3;i++)
	    average[i] = (a[i] + b[i]) / 2.0;
	return average;
}

/* This draws some mountains, which are very simple, so the animation	*/
/* isn't slowed down.	*/

void mountains()
{
	Coord mnt1p[3] = {80,50,0};
	Coord mnt1b1[3] = {80,-1.0,-50};
	Coord mnt1b2[3] = {80,-1.0,50};
	Coord mnt2p[3] = {75,40,-20};
	Coord mnt2b1[3] = {75,-1.0,-40};
	Coord mnt2b2[3] = {75,-1.0,0};
	Coord mnt3p[3] = {85,45,-45};
	Coord mnt3b1[3] = {85,-1,-70};
	Coord mnt3b2[3] = {85,-1,-5};

	short brown[3] = {116, 87, 11};
	short snow[3] = {196, 196, 196};

	bgnpolygon();
	  c3s(brown);v3f(mnt1b1);v3f(mnt1b2);
	  c3s(snow);v3f(mnt1p);
	endpolygon();

	bgnpolygon();
	  c3s(brown);v3f(mnt2b1);v3f(mnt2b2);
	  c3s(snow);v3f(mnt2p);
	endpolygon();

	bgnpolygon();
	  c3s(brown);v3f(mnt3b1);v3f(mnt3b2);
	  c3s(snow);v3f(mnt3p);
	endpolygon();
}

/* The folowing draws the entire scene. It takes the current rotation 	*/
/* of the ferris wheel and the number of points in the roller coaster	*/
/* arrays.  It returns the position of the ferris wheel rider.  	*/

Coord* drawScene(rotation, rollPts)
Coord rotation;
int rollPts;
{
	Coord fwv[3]; /* ferris wheel rider position	*/
	Coord gr1[3] = {100,-1.0,100};
	Coord gr2[3] = {100,-1.0,-100};
	Coord gr3[3] = {-100,-1.0,-100};
	Coord gr4[3] = {-100,-1.0,100};
	
	short grass[3] = {123, 193, 87};
	short sky[3] = {85, 172, 255};

	int i;

	c3s(sky);
        clear();
        zclear();

	/* Draw the ground */
	c3s(grass);
	bgnpolygon();
	v3f(gr1);v3f(gr2);v3f(gr3);v3f(gr4);
	endpolygon();

	/* Draw some mountains */
	mountains();

	coaster(rollPts);
	pushmatrix();
	  translate(-25.0,6.5,0);
          assignCoord(fwv,ferris(rotation));
	  fwv[0] += -25.0;
	  fwv[1] += 6.5;
	popmatrix();
        pushmatrix();
          translate(17,-1.0,-8);
          rotate(-900,'y');
          tent();
        popmatrix();
	pushmatrix();
	  translate(-22,-1,-11);
	  tent();
	popmatrix();

/*
	for(i=0; i<100000; i++);
*/

	return fwv;	/* return the position of the ferris wheel rider */
}

main(argc, argv)
int argc;
char **argv;
{
	Coord xl,yl,zl,xa,ya,za;  /* these are the lookat points */
	Coord rotation = 0.0;	/* the rotation of the ferris wheel */
	Coord fwv[3] = {0.0,-6.0,0.0};	/* initial Ferris wheel view */
	Coord rider[3], nextrider[3];	/* points for the coaster rider */
	int i, j, rollPts, tilt=0;
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
	  prefposition(0,1265,0,983);
	  winopen("carnival");
	  RGBmode();
	  doublebuffer();
	  gconfig();
	  mmode(MVIEWING);
	  perspective(600,1265.0/983.0,0.01,150.0);
	  zbuffer(TRUE);
	  }

	if (style == 1)
	  for(i=1;i<TRIPS*TOUR;i++)
	    {
	    loadmatrix(ID);
            lookat(fwv[0],fwv[1],fwv[2],fwv[0]+1.0,fwv[1],fwv[2],0);
	    assignCoord(fwv,drawScene(rotation,rollPts));
	    rotation -= WHEELROT;
	    swapbuffers();
	    }
	else if (style == 2)
	  for(j=1;j<=TRIPS;j++)
	    for(i=0;i<rollPts;i++)
	      {
	      assignCoord(rider, avgPts(rollerin[i], rollerout[i]));
	      assignCoord(nextrider, avgPts(rollerin[i+1], rollerout[i+1]));
	      loadmatrix(ID);
	/* These set the tilt of the roller coaster rider to simulate */
	/* the momentum.  They are just picked values.		      */
	      if ((i>=37 && i<=56)||(i>=174 && i<=193)||
		  (i>=233 && i<=238)||(i>=258 && i<=263))
		tilt = -15;
              else if ((i>=57 && i<=173)||(i>=239 && i<=262))
		tilt = -30;
	      else tilt = 0;
	      lookat(rider[0],rider[1]+0.5,rider[2],nextrider[0],
		     nextrider[1]+0.5,nextrider[2],tilt);
	      drawScene(rotation, rollPts);
	      rotation -= WHEELROT;
	      swapbuffers();
	      }
	else if (style == 3)
	  for(i=1; i < TRIPS * TOUR; i++)
	    {
	    loadmatrix(ID);
	    lookat(xl,yl,zl,xa,ya,za,0);
	    drawScene(rotation, rollPts);
	    rotation -= WHEELROT;
	    swapbuffers();
	    }
}
