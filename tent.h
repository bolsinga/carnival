/* Greg Bolsinga */
/* Tent */
/* April 28, 1992 */
/* cs319 */
/* Prof Hearn */

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
	bgnpolygon();
	  c3s(dkgrey);v3f(v0);
	  c3s(ltgrey);v3f(v1);
	  c3s(dkgrey);v3f(v2);v3f(v3);
	  c3s(ltgrey);v3f(v4);
	endpolygon();
	bgnpolygon();
	  c3s(dkgrey);v3f(v5);
	  c3s(ltgrey);v3f(v6);
	  c3s(dkgrey);v3f(v7);v3f(v8);
	  c3s(ltgrey);v3f(v9);
	endpolygon();

	/* Draw the back */
	bgnpolygon();
	  c3s(ltgrey);v3f(v1);
	  c3s(dkgrey);v3f(v2);
	  c3s(ltgrey);v3f(v7);
	  c3s(dkgrey);v3f(v6);
	endpolygon();

	/* Draw the front counter */
	c3s(blue);
	bgnpolygon();
	v3f(v0);v3f(v10);v3f(v11);v3f(v5);
	endpolygon();
	c3s(ltblue);
	bgnpolygon();
	v3f(v10);v3f(v12);v3f(v13);v3f(v11);
	endpolygon();

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
		c3s(red);
	  else c3s(ltpink);
	  bgnpolygon();
	  v3f(temp1);v3f(temp2);v3f(temp5);v3f(temp6);
	  endpolygon();
	  bgnpolygon();
	  v3f(temp2);v3f(temp3);v3f(temp4);v3f(temp5);
	  endpolygon();
	  pushmatrix();
	  translate(0,0,3.0);
	  arcf(center,2.0,temp6[0]-center,1800,0);
	  popmatrix();
	  assignCoord(temp1, temp6);
	  assignCoord(temp2, temp5);
	  assignCoord(temp3, temp4);
	  colorIsRed = !colorIsRed;
	  center += value;
	  }
}
