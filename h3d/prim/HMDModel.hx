package h3d.prim;

class HMDModel extends MeshPrimitive {

	var data : hxd.fmt.hmd.Data.Geometry;
	var dataPosition : Int;
	var indexCount : Int;
	var indexesTriPos : Array<Int>;
	var lib : hxd.fmt.hmd.Library;
	var curMaterial : Int;
	var collider : h3d.col.Collider;
	var normalsRecomputed : String;

	// Blendshapes
	var weights : Array<Float> = [];
	var index : Int = 0;
	var amount : Float = 0;
	var inputMapping : Array<Map<String, Int>> = [];
	var shapesBytes = [];

	public function new(data, dataPos, lib) {
		this.data = data;
		this.dataPosition = dataPos;
		this.lib = lib;

		if (getBlendshapeCount() <= 0)
			return;

		if ( data.vertexFormat.hasLowPrecision )
			throw "Blend shape doesn't support low precision";

		// Cache data for blendshapes
		var is32 = data.vertexCount > 0x10000;
		var vertexFormat = data.vertexFormat;
		var size = data.vertexCount * vertexFormat.strideBytes;
		var shapes = this.lib.header.shapes;

		for ( s in 0...shapes.length ) {
			var s = shapes[s];
			var size = s.vertexCount * s.vertexFormat.strideBytes;

			var vertexBytes = haxe.io.Bytes.alloc(size);
			lib.resource.entry.readBytes(vertexBytes, 0, dataPosition + s.vertexPosition, size);
			size = s.vertexCount << (is32 ? 2 : 1);

			var indexBytes = haxe.io.Bytes.alloc(size);
			lib.resource.entry.readBytes(indexBytes, 0, dataPosition + s.indexPosition, size);
			size = data.vertexCount << 2;

			var remapBytes = haxe.io.Bytes.alloc(size);
			lib.resource.entry.readBytes(remapBytes, 0, dataPosition + s.remapPosition, size);
			shapesBytes.push({ vertexBytes : vertexBytes, indexBytes : indexBytes, remapBytes : remapBytes});

			inputMapping.push(new Map());
		}

		// We want to remap inputs since inputs can be not exactly in the same
		for ( input in vertexFormat.getInputs() ) {
			for ( s in 0...shapes.length ) {
				var offset = 0;
				for ( i in shapes[s].vertexFormat.getInputs() ) {
					if ( i.name == input.name )
						inputMapping[s].set(i.name, offset);
					offset += i.type.getSize();
				}
			}
		}
	}

	override function hasInput( name : String ) {
		return super.hasInput(name) || data.vertexFormat.hasInput(name);
	}

	override function triCount() {
		return Std.int(data.indexCount / 3);
	}

	override function vertexCount() {
		return data.vertexCount;
	}

	override function getBounds() {
		return data.bounds;
	}

	override function selectMaterial( i : Int ) {
		curMaterial = i;
	}

	override function getMaterialIndexes(material:Int):{count:Int, start:Int} {
		return { start : indexesTriPos[material]*3, count : data.indexCounts[material] };
	}

	public function getDataBuffers(fmt, ?defaults,?material) {
		return lib.getBuffers(data, fmt, defaults, material);
	}

	public function loadSkin(skin) {
		lib.loadSkin(data, skin);
	}

	override function alloc(engine:h3d.Engine) {
		dispose();
		buffer = new h3d.Buffer(data.vertexCount, data.vertexFormat);

		var entry = lib.resource.entry;

		var size = data.vertexCount * data.vertexFormat.strideBytes;
		var bytes = entry.fetchBytes(dataPosition + data.vertexPosition, size);
		buffer.uploadBytes(bytes, 0, data.vertexCount);

		indexCount = 0;
		indexesTriPos = [];
		for( n in data.indexCounts ) {
			indexesTriPos.push(Std.int(indexCount/3));
			indexCount += n;
		}
		var is32 = data.vertexCount > 0x10000;
		indexes = new h3d.Indexes(indexCount, is32);

		var size = (is32 ? 4 : 2) * indexCount;
		var bytes = entry.fetchBytes(dataPosition + data.indexPosition, size);
		indexes.uploadBytes(bytes, 0, indexCount);

		if( normalsRecomputed != null ) {
			var name = normalsRecomputed;
			normalsRecomputed = null;
			recomputeNormals(name);
		}
	}

	public function recomputeNormals( ?name : String ) {

		if( normalsRecomputed != null )
			return;
		if( name != null && data.vertexFormat.hasInput(name) )
			return;

		if( name == null ) name = "normal";


		var pos = lib.getBuffers(data, hxd.BufferFormat.POS3D);
		var ids = new Array();
		var pts : Array<h3d.col.Point> = [];
		var mpts = new Map();

		for( i in 0...data.vertexCount ) {
			var added = false;
			var px = pos.vertexes[i * 3];
			var py = pos.vertexes[i * 3 + 1];
			var pz = pos.vertexes[i * 3 + 2];
			var pid = Std.int((px + py + pz) * 10.01);
			var arr = mpts.get(pid);
			if( arr == null ) {
				arr = [];
				mpts.set(pid, arr);
			} else {
				for( idx in arr ) {
					var p = pts[idx];
					if( p.x == px && p.y == py && p.z == pz ) {
						ids.push(idx);
						added = true;
						break;
					}
				}
			}
			if( !added ) {
				ids.push(pts.length);
				arr.push(pts.length);
				pts.push(new h3d.col.Point(px,py,pz));
			}
		}

		var idx = new hxd.IndexBuffer();
		for( i in pos.indexes )
			idx.push(ids[i]);

		var pol = new Polygon(pts, idx);
		pol.addNormals();

		var v = new hxd.FloatBuffer();
		v.grow(data.vertexCount*3);
		var k = 0;
		for( i in 0...data.vertexCount ) {
			var n = pol.normals[ids[i]];
			v[k++] = n.x;
			v[k++] = n.y;
			v[k++] = n.z;
		}
		var buf = h3d.Buffer.ofFloats(v, hxd.BufferFormat.make([{ name : name, type : DVec3 }]));
		addBuffer(buf);
		normalsRecomputed = name;
	}

	public function addTangents() {
		if( hasInput("tangent") )
			return;
		var pos = lib.getBuffers(data, hxd.BufferFormat.POS3D);
		var ids = new Array();
		var pts : Array<h3d.col.Point> = [];
		for( i in 0...data.vertexCount ) {
			var added = false;
			var px = pos.vertexes[i * 3];
			var py = pos.vertexes[i * 3 + 1];
			var pz = pos.vertexes[i * 3 + 2];
			for(i in 0...pts.length) {
				var p = pts[i];
				if(p.x == px && p.y == py && p.z == pz) {
					ids.push(i);
					added = true;
					break;
				}
			}
			if( !added ) {
				ids.push(pts.length);
				pts.push(new h3d.col.Point(px,py,pz));
			}
		}
		var idx = new hxd.IndexBuffer();
		for( i in pos.indexes )
			idx.push(ids[i]);
		var pol = new Polygon(pts, idx);
		pol.addNormals();
		pol.addTangents();
		var v = new hxd.FloatBuffer();
		v.grow(data.vertexCount*3);
		var k = 0;
		for( i in 0...data.vertexCount ) {
			var t = pol.tangents[ids[i]];
			v[k++] = t.x;
			v[k++] = t.y;
			v[k++] = t.z;
		}
		var buf = h3d.Buffer.ofFloats(v, hxd.BufferFormat.make([{ name : "tangent", type : DVec3 }]));
		addBuffer(buf);
	}

	override function render( engine : h3d.Engine ) {
		if( curMaterial < 0 ) {
			super.render(engine);
			return;
		}
		if( indexes == null || indexes.isDisposed() )
			alloc(engine);
		if( buffers == null )
			engine.renderIndexed(buffer, indexes, indexesTriPos[curMaterial], Std.int(data.indexCounts[curMaterial]/3));
		else
			engine.renderMultiBuffers(formats, buffers, indexes, indexesTriPos[curMaterial], Std.int(data.indexCounts[curMaterial]/3));
		curMaterial = -1;
	}

	function initCollider( poly : h3d.col.PolygonBuffer ) {
		var buf= lib.getBuffers(data, hxd.BufferFormat.POS3D);
		poly.setData(buf.vertexes, buf.indexes);
		if( collider == null ) {
			var sphere = data.bounds.toSphere();
			collider = new h3d.col.Collider.OptimizedCollider(sphere, poly);
		}
	}

	override function getCollider() {
		if( collider != null )
			return collider;
		var poly = new h3d.col.PolygonBuffer();
		poly.source = {
			entry : lib.resource.entry,
			geometryName : null,
		};
		for( h in lib.header.models )
			if( lib.header.geometries[h.geometry] == data ) {
				poly.source.geometryName = h.name;
				break;
			}
		initCollider(poly);
		return collider;
	}

	public function setBlendshapeAmount(blendshapeIdx: Int, amount: Float) {
		this.index = blendshapeIdx;
		this.amount = amount;

		uploadBlendshapeBytes();
	}

	public function getBlendshapeCount() {
		if (lib.header.shapes == null)
			return 0;

		return lib.header.shapes.length;
	}

	public function uploadBlendshapeBytes() {
		var is32 = data.vertexCount > 0x10000;
		var vertexFormat = data.vertexFormat;
		buffer = new h3d.Buffer(data.vertexCount, vertexFormat);

		var size = data.vertexCount * vertexFormat.strideBytes;
		var originalBytes = haxe.io.Bytes.alloc(size);
		lib.resource.entry.readBytes(originalBytes, 0, dataPosition + data.vertexPosition, size);

		var shapes = this.lib.header.shapes;
		weights = [];

		for ( s in 0...shapes.length )
			weights[s] = s == index ? amount : 0.0;

		var flagOffset = 31;
		var bytes = haxe.io.Bytes.alloc(originalBytes.length);
		bytes.blit(0, originalBytes, 0, originalBytes.length);

		// Apply blendshapes offsets to original vertex
		for (sIdx in 0...shapes.length) {
			if (sIdx != index)
				continue;

			var sp = shapesBytes[sIdx];
			var offsetIdx = 0;
			var idx = 0;

			while (offsetIdx < shapes[sIdx].indexCount) {
				var affectedVId = sp.remapBytes.getInt32(idx << 2);

				var reachEnd = false;
				while (!reachEnd) {
					reachEnd = affectedVId >> flagOffset != 0;
					if (reachEnd)
						affectedVId = affectedVId ^ (1 << flagOffset);

					var inputIdx = 0;
					var offsetInput = 0;
					for (input in shapes[sIdx].vertexFormat.getInputs()) {
						for (sizeIdx in 0...input.type.getSize()) {
							var original = originalBytes.getFloat(affectedVId * vertexFormat.stride + inputMapping[sIdx][input.name] + sizeIdx << 2);
							var offset = sp.vertexBytes.getFloat(offsetIdx * shapes[sIdx].vertexFormat.stride + offsetInput + sizeIdx << 2);

							var res = hxd.Math.lerp(original, original + offset, weights[sIdx]);
							bytes.setFloat(affectedVId * vertexFormat.stride + inputMapping[sIdx][input.name] + sizeIdx << 2, res);
						}

						offsetInput += input.type.getSize();
						inputIdx++;
					}

					idx++;

					if (idx < data.vertexCount)
						affectedVId = sp.remapBytes.getInt32(idx << 2);
				}

				offsetIdx++;
			}
		}

		// Send bytes to buffer for rendering
		buffer.uploadBytes(bytes, 0, data.vertexCount);
		indexCount = 0;
		indexesTriPos = [];
		for( n in data.indexCounts ) {
			indexesTriPos.push(Std.int(indexCount/3));
			indexCount += n;
		}

		indexes = new h3d.Indexes(indexCount, is32);
		var size = (is32 ? 4 : 2) * indexCount;
		var bytes = lib.resource.entry.fetchBytes(dataPosition + data.indexPosition, size);
		indexes.uploadBytes(bytes, 0, indexCount);
	}
}