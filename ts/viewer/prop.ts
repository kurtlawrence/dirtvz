
/*
	* A set of properties and attributes an object can have.
	*/
export class Properties {
	colour: Colour = [222, 184, 135];
}

/* A colour represented by 3 8 bit integers [r,g,b] */
type Colour = number[];
