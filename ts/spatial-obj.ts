export { SpatialObject };

/**
	* A reference to a loaded object in a `Viewer`.
	* 
	* The main object is stored in the `Store`.
	*/
class SpatialObject {
	key: string;
	status: Status = Status.Unloaded;

	constructor(key: string) {
		this.key = key;
	}
}

enum Status {
	Unloaded,
	Preprocessing,
	Loaded,
}

