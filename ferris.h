/* Greg Bolsinga */
/* Ferris Wheel */
/* April 28, 1992 */
/* cs319  Prof Hearn */

#define PI acos(-1.0)
#define SPOKE PI / 4.0  /* position of the spokes in radians */

/* The following draws the ferris wheel carriage. It gets the points */
/* of the spokes on both sides, and draws it right in the middle.    */

void carriage(wheel1, wheel2)
Coord wheel1[3], wheel2[3];
{
	Coord v1[3],v2[3],v3[3],v4[3],v5[3],v6[3];
	Coord v7[3],v8[3],v9[3],v10[3],v11[3],v12[3];
	Coord side1[3], side2[3];

	short dkgrey[3] = {76, 66, 102};
	short dkrgrey[3] = {40, 40, 40};
	short blue[3] = {66, 66, 230};
	short steel[3] = {65, 74, 82};
	
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
	c3s(dkgrey);
	bgnpolygon(); /* back of chair */
	v3f(v1);v3f(v2);v3f(v3);v3f(v4);
	endpolygon();
	c3s(dkrgrey);
	bgnpolygon(); /* seat of chair */
	v3f(v4);v3f(v3);v3f(v10);v3f(v9);
	endpolygon();
	c3s(dkgrey);
	bgnpolygon(); /* foot part */
	v3f(v11);v3f(v12);v3f(v10);v3f(v9);
	endpolygon();
	c3s(blue);
	bgnpolygon(); /*one side*/
	v3f(v4);v3f(v5);v3f(v7);v3f(v9);
	endpolygon();
	bgnpolygon(); /*other side*/
	v3f(v3);v3f(v6);v3f(v8);v3f(v10);
	endpolygon();
	c3s(steel);
	bgnline(); /*draw axels */
	v3f(side1);v3f(wheel1);
	endline();
	bgnline();
	v3f(side2);v3f(wheel2);
	endline();
}
	
/* The following draws the ferris wheel and returns the position of the */
/* rider, who initially starts off at the bottom at 6*PI/4 radians	*/
/* It recieves the current angle of rotation.  This way the wheel 	*/
/* rotates when the angle changes.					*/

Coord* ferris(angle)
Coord angle;
{
	int i;
	float j;
	Coord bottom; /* the angle of the 'bottom' spoke */
	Coord center1[3] = {0.0,0.0,1.5};
	Coord center2[3] = {0.0,0.0,-1.5};
	Coord axel1[3] = {0.0,0.0,2.5};
	Coord axel2[3] = {0.0,0.0,-2.5};
	Coord b1[3] = {-4.5,-7.0,3.0};
	Coord b2[3] = {4.5,-7.0,3.0};
	Coord b3[3] = {4.5,-7.0,-3.0};
	Coord b4[3] = {-4.5,-7.0,-3.0};
	Coord temp1[8][3], temp2[8][3];
	Coord sight[3];

	short yellow[3] = {255, 255, 40};
	short steel[3] = {65, 74, 82};

	linewidth(2);
	c3s(yellow);
	pushmatrix();
	translate(0.0,0.0,-1.5);
	circ(0.0,0.0,6.0);
	popmatrix();
	pushmatrix();
	translate(0.0,0.0,1.5);
	circ(0.0,0.0,6.0);
	popmatrix();
	for(i=0; i<=7; i++)
	{
		if (i==6) /* this is the rider position */
			bottom = angle;
		temp1[i][0] = 6.0*cos(angle);
		temp1[i][1] = 6.0*sin(angle);
		temp1[i][2] = 1.5;
		assignCoord(temp2[i], temp1[i]);
		temp2[i][2] = -1.5;
		bgnline();
		v3f(temp1[i]);v3f(center1);
		endline();
		bgnline();
		v3f(temp2[i]);v3f(center2);
		endline();
		carriage(temp1[i], temp2[i]);
		c3s(yellow);
		angle += SPOKE;
	}
	c3s(steel);
	linewidth(4);
	bgnline();
	v3f(axel1);v3f(axel2);
	endline();
	bgnline();
	v3f(b1);v3f(axel1);v3f(b2);
	endline();
	bgnline();
	v3f(b3);v3f(axel2);v3f(b4);
	endline();
	sight[0] = 6.0*cos(bottom-0.1);
	sight[1] = 6.0*sin(bottom-0.1) + 0.5;
	sight[2] = 0.0;
	linewidth(1);
	return sight;	/* Returns position of 'bottom' spoke of the next */
			/* iteration (angle - 0.1 is the next iteration) */
}
