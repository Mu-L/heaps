package h3d.pass;

class DirShadowMap extends Shadows {

	var depth : h3d.mat.Texture;
	var dshader : h3d.shader.DirShadow;
	var border : Border;
	var mergePass = new h3d.pass.ScreenFx(new h3d.shader.MinMaxShader());
	var boundingObject : h3d.scene.Object;

	/**
		Shrink the frustum of the light to the bounds containing all visible objects
	**/
	public var autoShrink = true;
	/**
		For top down lights and cameras, use scene Z min/max to optimize shadowmap. Requires autoShrink
	**/
	public var autoZPlanes = false;
	/**
		Clamp the zFar of the frustum of the camera for bounds calculation
	**/
	public var maxDist = -1.0;
	/**
		Clamp the zNear of the frustum of the camera for bounds calculation
	**/
	public var minDist = -1.0;

	public function new( light : h3d.scene.Light ) {
		super(light);
		lightCamera = new h3d.Camera();
		lightCamera.orthoBounds = new h3d.col.Bounds();
		shader = dshader = new h3d.shader.DirShadow();
		border = new Border(size, size);
	}

	override function set_mode(m:Shadows.RenderMode) {
		dshader.enable = m != None;
		return mode = m;
	}

	override function set_enabled(b:Bool) {
		dshader.enable = b && mode != None;
		return enabled = b;
	}

	override function set_size(s) {
		if( border != null && size != s ) {
			border.dispose();
			border = new Border(s, s);
		}
		return super.set_size(s);
	}

	override function dispose() {
		super.dispose();
		if( depth != null ) depth.dispose();
		if ( border != null ) border.dispose();
	}

	public override function getShadowTex() {
		return dshader.shadowMap;
	}

	public dynamic function calcShadowBounds( camera : h3d.Camera ) {
		var bounds = camera.orthoBounds;
		var zMax = -1e9, zMin = 1e9;
		if( autoShrink ) {
			// add visible casters in light camera position
			var mtmp = new h3d.Matrix();
			var identity = h3d.Matrix.I();
			var btmp = autoZPlanes ? new h3d.col.Bounds() : null;
			var obj = boundingObject != null ? boundingObject : ctx.scene;
			obj.iterVisibleMeshes(function(m) {
				if( m.primitive == null || !m.material.castShadows ) return;
				var b = m.primitive.getBounds();
				if( b.xMin > b.xMax ) return;

				var absPos = m.primitive is h3d.prim.Instanced ? identity : m.getAbsPos();
				if( autoZPlanes ) {
					btmp.load(b);
					btmp.transform(absPos);
					if( btmp.zMax > zMax ) zMax = btmp.zMax;
					if( btmp.zMin < zMin ) zMin = btmp.zMin;
				}

				mtmp.multiply3x4(absPos, camera.mcam);

				var p = new h3d.col.Point(b.xMin, b.yMin, b.zMin);
				p.transform(mtmp);
				bounds.addPoint(p);

				var p = new h3d.col.Point(b.xMin, b.yMin, b.zMax);
				p.transform(mtmp);
				bounds.addPoint(p);

				var p = new h3d.col.Point(b.xMin, b.yMax, b.zMin);
				p.transform(mtmp);
				bounds.addPoint(p);

				var p = new h3d.col.Point(b.xMin, b.yMax, b.zMax);
				p.transform(mtmp);
				bounds.addPoint(p);

				var p = new h3d.col.Point(b.xMax, b.yMin, b.zMin);
				p.transform(mtmp);
				bounds.addPoint(p);

				var p = new h3d.col.Point(b.xMax, b.yMin, b.zMax);
				p.transform(mtmp);
				bounds.addPoint(p);

				var p = new h3d.col.Point(b.xMax, b.yMax, b.zMin);
				p.transform(mtmp);
				bounds.addPoint(p);

				var p = new h3d.col.Point(b.xMax, b.yMax, b.zMax);
				p.transform(mtmp);
				bounds.addPoint(p);

			});
		} else {
			if( mode == Dynamic )
				bounds.all();
		}

		if( mode == Dynamic ) {

			// Intersect with frustum bounds
			var cameraBounds = new h3d.col.Bounds();
			var minDist = minDist < 0 ? ctx.camera.zNear : minDist;
			var maxDist = maxDist < 0 ? ctx.camera.zFar : maxDist;

			inline function addCorner(x,y,d) {
				var dist = d?minDist:maxDist;
				var pt = ctx.camera.unproject(x,y,ctx.camera.distanceToDepth(dist)).toPoint();
				if( autoShrink && autoZPlanes ) {
					// let's auto limit our frustrum to our zMin/Max planes
					var r = h3d.col.Ray.fromPoints(ctx.camera.pos.toPoint(), pt);
					var d2 = r.distance(h3d.col.Plane.Z(d?zMax:zMin));
					var k = d ? 1 : -1;
					if( d2 > 0 && d2*k > dist*k )
						pt.load(r.getPoint(d2));
				}
				pt.transform(camera.mcam);
				cameraBounds.addPos(pt.x, pt.y, pt.z);
			}

			inline function addCorners(d) {
				addCorner(-1,-1,d);
				addCorner(-1,1,d);
				addCorner(1,-1,d);
				addCorner(1,1,d);
			}

			addCorners(true);
			addCorners(false);

			if( autoShrink ) {
				// Keep the zMin from the bounds of visible objects
				// Prevent shadows inside frustum from objects outside frustum being clipped
				cameraBounds.zMin = bounds.zMin;
				bounds.intersection(bounds, cameraBounds);
				if( autoZPlanes ) {
					/*
						Let's intersect again our light camera bounds with our scene zMax plane
						so we can tighten the zMin, which will give us better precision
						for our depth map.
					*/
					var v = camera.target.sub(camera.pos).normalized();
					var dMin = 1e9;
					for( dx in 0...2 )
						for( dy in 0...2 ) {
							var px = dx > 0 ? bounds.xMax : bounds.xMin;
							var py = dy > 0 ? bounds.yMax : bounds.yMin;
							var r0 = new h3d.col.Point(px,py,bounds.zMin).transformed(camera.getInverseView());
							var r = h3d.col.Ray.fromValues(r0.x, r0.y, r0.z, v.x, v.y, v.z);
							var d = r.distance(h3d.col.Plane.Z(zMax));
							if( d < dMin ) dMin = d;
						}
					bounds.zMin += dMin;
				}
			}
			else
				bounds.load( cameraBounds );
		}
		bounds.scaleCenter(1.01);
	}

	override function syncShader(texture) {
		dshader.shadowMap = texture;
		dshader.shadowMapChannel = format == h3d.mat.Texture.nativeFormat ? PackedFloat : R;
		dshader.shadowBias = bias;
		dshader.shadowPower = power;
		dshader.shadowProj = getShadowProj();

		//ESM
		dshader.USE_ESM = samplingKind == ESM;
		dshader.shadowPower = power;

		// PCF
		dshader.USE_PCF = samplingKind == PCF;
		dshader.shadowRes.set(texture.width,texture.height);
		dshader.pcfScale = pcfScale;
		dshader.pcfQuality = pcfQuality;
	}

	override function saveStaticData() {
		if( mode != Mixed && mode != Static )
			return null;
		if( staticTexture == null )
			throw "Data not computed";
		var bytes = haxe.zip.Compress.run(staticTexture.capturePixels().bytes,9);
		var buffer = new haxe.io.BytesBuffer();
		buffer.addInt32(staticTexture.width);
		buffer.addFloat(lightCamera.pos.x);
		buffer.addFloat(lightCamera.pos.y);
		buffer.addFloat(lightCamera.pos.z);
		buffer.addFloat(lightCamera.target.x);
		buffer.addFloat(lightCamera.target.y);
		buffer.addFloat(lightCamera.target.z);
		buffer.addFloat(lightCamera.orthoBounds.xMin);
		buffer.addFloat(lightCamera.orthoBounds.yMin);
		buffer.addFloat(lightCamera.orthoBounds.zMin);
		buffer.addFloat(lightCamera.orthoBounds.xMax);
		buffer.addFloat(lightCamera.orthoBounds.yMax);
		buffer.addFloat(lightCamera.orthoBounds.zMax);
		buffer.addInt32(bytes.length);
		buffer.add(bytes);
		return buffer.getBytes();
	}

	override function loadStaticData( bytes : haxe.io.Bytes ) {
		if( (mode != Mixed && mode != Static) || bytes == null )
			return false;
		var buffer = new haxe.io.BytesInput(bytes);
		var size = buffer.readInt32();
		if( size != this.size )
			return false;
		lightCamera.pos.x = buffer.readFloat();
		lightCamera.pos.y = buffer.readFloat();
		lightCamera.pos.z = buffer.readFloat();
		lightCamera.target.x = buffer.readFloat();
		lightCamera.target.y = buffer.readFloat();
		lightCamera.target.z = buffer.readFloat();
		lightCamera.orthoBounds.xMin = buffer.readFloat();
		lightCamera.orthoBounds.yMin = buffer.readFloat();
		lightCamera.orthoBounds.zMin = buffer.readFloat();
		lightCamera.orthoBounds.xMax = buffer.readFloat();
		lightCamera.orthoBounds.yMax = buffer.readFloat();
		lightCamera.orthoBounds.zMax = buffer.readFloat();
		lightCamera.update();
		var len = buffer.readInt32();
		var pixels = new hxd.Pixels(size, size, haxe.zip.Uncompress.run(buffer.read(len)), format);
		if( staticTexture != null ) staticTexture.dispose();
		staticTexture = new h3d.mat.Texture(size, size, [Target], format);
		staticTexture.uploadPixels(pixels);
		staticTexture.name = "staticTexture";
		staticTexture.preventAutoDispose();
		syncShader(staticTexture);
		return true;
	}

	function processShadowMap( passes, tex, ?sort) {
		var prevViewProj = @:privateAccess ctx.cameraViewProj;
		@:privateAccess ctx.cameraViewProj = getShadowProj();
		if ( tex.isDepth() ) {
			ctx.engine.pushDepth(tex);
			ctx.engine.clear(null, 1.0);
		}
		else {
			ctx.engine.pushTarget(tex);
			ctx.engine.clear(0xFFFFFF, 1.0);
		}
		super.draw(passes, sort);

		var computingStatic = ctx.computingStatic || updateStatic;

		var doBlur = blur.radius > 0 && (mode != Mixed || !computingStatic);

		if( border != null && !doBlur )
			border.render();

		ctx.engine.popTarget();

		if( mode == Mixed && !computingStatic && staticTexture != null && !staticTexture.isDisposed() ) {
			if ( staticTexture.width != tex.width )
				throw "Static shadow map doesnt match dynamic shadow map";
			var merge = ctx.textures.allocTarget("mergedDirShadowMap", size, size, false, format);
			mergePass.shader.texA = tex;
			mergePass.shader.texB = staticTexture;
			ctx.engine.pushTarget(merge);
			mergePass.render();
			ctx.engine.popTarget();
			tex = merge;
		}

		if( doBlur ) {
			if ( tex.isDepth() ) {
				var tmp = ctx.textures.allocTarget("dirShadowMapFloat", size, size, false, format);
				h3d.pass.Copy.run(tex, tmp);
				tex = tmp;
			}
			blur.apply(ctx, tex);
			if( border != null ) {
				ctx.engine.pushTarget(tex);
				border.render();
				ctx.engine.popTarget();
			}
		}

		@:privateAccess ctx.cameraViewProj = prevViewProj;

		return tex;
	}

	var g : h3d.scene.Graphics;
	public var debug : Bool;
	override function draw( passes, ?sort ) {
		if( !enabled )
			return;

		if( !filterPasses(passes) )
			return;

		var computingStatic = ctx.computingStatic || updateStatic;

		if( mode != Mixed || computingStatic ) {
			var ct = ctx.camera.target;
			var slight = light == null ? ctx.lightSystem.shadowLight : light;
			var ldir = slight == null ? null : @:privateAccess slight.getShadowDirection();
			if( ldir == null )
				lightCamera.target.set(0, 0, -1);
			else {
				lightCamera.target.set(ldir.x, ldir.y, ldir.z);
				lightCamera.target.normalize();
			}
			lightCamera.target.x += ct.x;
			lightCamera.target.y += ct.y;
			lightCamera.target.z += ct.z;
			lightCamera.pos.load(ct);
			lightCamera.update();

			lightCamera.orthoBounds.empty();
			if( !passes.isEmpty() ) calcShadowBounds(lightCamera);
			lightCamera.update();
		}

		cullPasses(passes,function(col) return col.inFrustum(lightCamera.frustum));

		#if js
		var texture = ctx.textures.allocTarget("dirShadowMap", size, size, false, format);
		if( depth == null || depth.width != size || depth.height != size || depth.isDisposed() ) {
			if( depth != null ) depth.dispose();
			depth = new h3d.mat.Texture(size, size, hxd.PixelFormat.Depth24Stencil8);
			depth.name = "dirShadowMapDepth";
		}
		texture.depthBuffer = depth;
		#else
		depth = ctx.textures.allocTarget("dirShadowMap", size, size, false, hxd.PixelFormat.Depth24Stencil8);
		var texture = depth;
		#end

		texture = processShadowMap(passes, texture, sort);

		syncShader(texture);

		updateStatic = false;
		
		#if editor
		drawDebug();
		#end
	}

	override function computeStatic( passes : h3d.pass.PassList ) {
		if( mode != Static && mode != Mixed )
			return;
		draw(passes);
		var texture = dshader.shadowMap;
		var old = staticTexture;
		staticTexture = texture.clone();
		staticTexture.name = "StaticDirShadowMap";
		staticTexture.preventAutoDispose();
		dshader.shadowMap = staticTexture;
		if( old != null )
			old.dispose();
	}

	function drawDebug() {
		if( g == null ) {
			g = new h3d.scene.Graphics(ctx.scene);
			g.name = "frustumDebug";
			g.material.mainPass.setPassName("overlay");
			g.ignoreBounds = true;
		}
		if ( !debug )
			return;
		g.clear();

		drawBounds(lightCamera.getInverseViewProj(), 0xffffff);
	}

	function drawBounds(invViewModel : h3d.Matrix, color : Int) {

		inline function unproject(screenX, screenY, camZ) {
			var p = new h3d.Vector(screenX, screenY, camZ);
			p.project(invViewModel);
			return p;
		}

		var nearPlaneCorner = [unproject(-1, 1, 0), unproject(1, 1, 0), unproject(1, -1, 0), unproject(-1, -1, 0)];
		var farPlaneCorner = [unproject(-1, 1, 1), unproject(1, 1, 1), unproject(1, -1, 1), unproject(-1, -1, 1)];

		g.lineStyle(1, color);

		// Near Plane
		var last = nearPlaneCorner[nearPlaneCorner.length - 1];
		inline function moveTo(x : Float, y : Float, z : Float) {
			g.moveTo(x - ctx.scene.x, y - ctx.scene.y, z - ctx.scene.z);
		}
		inline function lineTo(x : Float, y : Float, z : Float) {
			g.lineTo(x - ctx.scene.x, y - ctx.scene.y, z - ctx.scene.z);
		}
		moveTo(last.x,last.y,last.z);
		for( fc in nearPlaneCorner ) {
			lineTo(fc.x, fc.y, fc.z);
		}

		// Far Plane
		var last = farPlaneCorner[farPlaneCorner.length - 1];
		moveTo(last.x,last.y,last.z);
		for( fc in farPlaneCorner ) {
			lineTo(fc.x, fc.y, fc.z);
		}

		// Connections
		for( i in 0 ... 4 ) {
			var np = nearPlaneCorner[i];
			var fp = farPlaneCorner[i];
			moveTo(np.x, np.y, np.z);
			lineTo(fp.x, fp.y, fp.z);
		}
	}
}