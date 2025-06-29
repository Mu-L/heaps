package h3d.prim;

/**
	h3d.prim.Primitive is the base class for all 3D primitives.
	You can't create an instance of it and need to use one of its subclasses.
**/
class Primitive {

	/**
		The primitive vertex buffer, holding its vertexes data.
	**/
	public var buffer : Buffer;

	/**
		The primitive indexes buffer, holding its triangles indices.
	**/
	public var indexes : Indexes;

	/**
		Allow user to force a specific lod index. If set to -1, forced lod will be ignored.
	**/
	public var forcedLod : Int = -1;

	/**
		Current amount of references to this Primitive.
		Use `incref` and `decref` methods to affect this value. If it reaches 0, it will be automatically disposed.
	**/
	public var refCount(default, null) : Int = 0;

	/**
		The number of triangles the primitive has.
	**/
	public function triCount() {
		return if( indexes != null ) Std.int(indexes.count / 3) else if( buffer == null ) 0 else Std.int(buffer.vertices / 3);
	}

	/**
		The number of vertexes the primitive has.
	**/
	public function vertexCount() {
		return 0;
	}

	/**
		Return a local collider for the primitive
	**/
	public function getCollider() : h3d.col.Collider {
		throw "not implemented for "+this;
		return null;
	}

	/**
		Return the bounds for the primitive
	**/
	public function getBounds() : h3d.col.Bounds {
		throw "not implemented for "+this;
		return null;
	}

	/**
		Increase reference count of the Primitive.
	**/
	public function incref():Void
	{
		refCount++;
	}

	/**
		Decrease reference count of the Primitive.
		If recount reaches zero, Primitive is automatically disposed when last referencing mesh is removed from scene.
	**/
	public function decref():Void
	{
		refCount--;
		if ( refCount <= 0 ) {
			refCount = 0;
			dispose();
		}
	}

	/**
		Allocate the primitive on GPU. Used for internal usage.
	**/
	public function alloc( engine : h3d.Engine ) {
		throw "not implemented";
	}

	/**
		Select the specified sub material before drawin. Used for internal usage.
	**/
	public function selectMaterial( material : Int, lod : Int ) {
	}

	/**
		Returns the number and offset of indexes for the specified material
	**/
	public function getMaterialIndexes( material : Int, lod : Int = 0 ) : { count : Int, start : Int } {
		if ( lod != 0 ) return { start : 0, count : 0 };
		return { start : getMaterialIndexStart(material, lod), count : getMaterialIndexCount(material, lod) };
	}

	public function getMaterialIndexStart( material : Int, lod : Int = 0 ) : Int {
		return 0;
	}

	public function getMaterialIndexCount( material : Int, lod : Int = 0 ) : Int {
		return indexes == null ? triCount() * 3 : indexes.count;
	}

	@:noCompletion public function buildNormalsDisplay() : Primitive {
		throw "not implemented for "+this;
		return null;
	}

	/**
		Render the primitive. Used for internal usage.
	**/
	public function render( engine : h3d.Engine ) {
		if( buffer == null || buffer.isDisposed() ) alloc(engine);
		if( indexes == null )
			engine.renderTriBuffer(buffer);
		else
			engine.renderIndexed(buffer,indexes);
	}

	/**
		Dispose the primitive, freeing the GPU memory it uses.
	**/
	public function dispose() {
		if( buffer != null ) {
			buffer.dispose();
			buffer = null;
		}
		if( indexes != null ) {
			indexes.dispose();
			indexes = null;
		}
	}

	/**
		Return the primitive type.
	**/
	public function toString() {
		return Type.getClassName(Type.getClass(this)).split(".").pop();
	}

	/**
	 	Return the LOD count.
	**/
	public function lodCount() {
		return 1;
	}

	public function screenRatioToLod ( screenRatio : Float ) : Int {
		return 0;
	}

}