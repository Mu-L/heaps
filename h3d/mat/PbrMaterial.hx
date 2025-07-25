package h3d.mat;

enum abstract PbrMode(String) {
	var PBR = "PBR";
	var Forward = "Forward";
	var Overlay = "Overlay";
	var Decal = "Decal";
	var BeforeTonemapping = "BeforeTonemapping";
	var BeforeTonemappingDecal = "BeforeTonemappingDecal";
	var AfterTonemapping = "AfterTonemapping";
	var AfterTonemappingDecal = "AfterTonemappingDecal";
	var Distortion = "Distortion";
	var DecalPass = "DecalPass";
	var TerrainPass = "TerrainPass";
}

enum abstract PbrBlend(String) {
	var None = "None";
	var Alpha = "Alpha";
	var Add = "Add";
	var AlphaAdd = "AlphaAdd";
	var Multiply = "Multiply";
	var AlphaMultiply = "AlphaMultiply";
}

enum abstract PbrDepthTest(String) {
	var Less = "Less";
	var LessEqual = "LessEqual";
	var Greater = "Greater";
	var GreaterEqual = "GreaterEqual";
	var Always = "Always";
	var Never = "Never";
	var Equal = "Equal";
	var NotEqual= "NotEqual";
}

enum abstract PbrDepthWrite(String) {
	var Default = "Default";
	var On = "On";
	var Off = "Off";
}

enum abstract PbrStencilOp(String) {
	var Keep = "Keep";
	var Zero = "Zero";
	var Replace = "Replace";
	var Increment = "Increment";
	var IncrementWrap = "IncrementWrap";
	var Decrement = "Decrement";
	var DecrementWrap = "DecrementWrap";
	var Invert = "Invert";
}

enum abstract PbrStencilCompare(String) {
	var Always = "Always";
	var Never = "Never";
	var Equal = "Equal";
	var NotEqual = "NotEqual";
	var Greater = "Greater";
	var GreaterEqual = "GreaterEqual";
	var Less = "Less";
	var LessEqual = "LessEqual";
}

enum abstract PbrCullingMode(String) {
	var None = "None";
	var Back = "Back";
	var Front = "Front";
	var Both = "Both";
}

typedef PbrProps = {
	var mode : PbrMode;
	var blend : PbrBlend;
	var shadows : Bool;
	var culling : PbrCullingMode;
	var depthTest : PbrDepthTest;
	@:optional var depthWrite : PbrDepthWrite;
	var colorMask : Int;
	@:optional var alphaKill : Bool;
	@:optional var emissive : Float;
	@:optional var parallax : Float;
	@:optional var parallaxSteps : Int;
	@:optional var textureWrap : Bool;

	var enableStencil : Bool;
	@:optional var stencilCompare : PbrStencilCompare;
	@:optional var stencilPassOp : PbrStencilOp;
	@:optional var stencilFailOp : PbrStencilOp;
	@:optional var depthFailOp : PbrStencilOp;
	@:optional var stencilValue : Int;
	@:optional var stencilWriteMask : Int;
	@:optional var stencilReadMask : Int;

	@:optional var drawOrder : String;
	@:optional var depthPrepass : Bool;
	@:optional var flipBackFaceNormal : Bool;
	@:optional var ignoreCollide : Bool;
}

class PbrMaterial extends Material {

	override function set_blendMode(b:BlendMode) {
		if( mainPass != null ) {
			mainPass.setBlendMode(b);
			var dwrite = props != null ? (props:PbrProps).depthWrite : null;
			if(dwrite != null && dwrite != Default)
				mainPass.depthWrite = dwrite == On;
			else
				mainPass.depthWrite = b == None;
			var am = mainPass.getShader(h3d.shader.pbr.AlphaMultiply);
			if( b == AlphaMultiply ) {
				if( am == null ) {
					am = new h3d.shader.pbr.AlphaMultiply();
					am.setPriority(-1);
					mainPass.addShader(am);
				}
			} else if( am != null )
				mainPass.removeShader(am);
			var mode = props == null ? PBR : (props:PbrProps).mode;
			switch( mode ) {
			case PBR:
				mainPass.setPassName(switch( b ) {
				case Add, AlphaAdd, SoftAdd: "additive";
				case Alpha, AlphaMultiply: "alpha";
				default: "default";
				});
			case Forward:
				mainPass.setPassName(switch( b ) {
				case Alpha, AlphaMultiply: "forwardAlpha";
				default: "forward";
				});
			default:
			}
		}
		return this.blendMode = b;
	}

	override function set_receiveShadows(b) {
		// don't add shadows shader here, we are not in forward
		return receiveShadows = b;
	}

	override function getDefaultProps( ?type : String ) : Any {
		var props : PbrProps;
		switch( type ) {
		case "particles3D", "trail3D":
			props = {
				mode : PBR,
				blend : Alpha,
				shadows : false,
				culling : None,
				depthTest : Less,
				colorMask : 1 << 0 | 1 << 1 | 1 << 2 | 1 << 3,
				enableStencil : false,
			};
		case "ui":
			props = {
				mode : Overlay,
				blend : Alpha,
				shadows : false,
				culling : None,
				alphaKill : true,
				depthTest : Less,
				colorMask : 1 << 0 | 1 << 1 | 1 << 2 | 1 << 3,
				enableStencil : false,
			};
		case "decal":
			props = {
				mode : Decal,
				blend : Alpha,
				shadows : false,
				culling : Back,
				depthTest : Less,
				colorMask : 1 << 0 | 1 << 1 | 1 << 2 | 1 << 3,
				enableStencil : false,
			};
		default:
			props = {
				mode : PBR,
				blend : None,
				shadows : true,
				culling : Back,
				depthTest : Less,
				colorMask : 1 << 0 | 1 << 1 | 1 << 2 | 1 << 3,
				enableStencil : false,
			};
		}
		return props;
	}

	override function getDefaultModelProps() : Any {
		var props : PbrProps = getDefaultProps();
		props.blend = switch( blendMode ) {
			case None: None;
			case Alpha: Alpha;
			case Add: Add;
			case Multiply: Multiply;
			case AlphaMultiply: AlphaMultiply;
			default: throw "Unsupported Model blendMode "+blendMode;
		}
		props.depthTest = switch (mainPass.depthTest) {
			case Always: Always;
			case Never: Never;
			case Equal: Equal;
			case NotEqual: NotEqual;
			case Greater: Greater;
			case GreaterEqual: GreaterEqual;
			case Less: Less;
			case LessEqual: LessEqual;
		}
		return props;
	}

	function resetProps() {
		var props : PbrProps = props;
		mainPass.enableLights = true;

		// Backward compatibility
		if( (props:Dynamic).culling is Bool )
			props.culling = (props:Dynamic).culling ? Back : None;
		#if editor
		if( (props:Dynamic).colorMask == null ) props.colorMask = 15;

		// Remove unused fields
		if( props.emissive == 0 )
			Reflect.deleteField(props,"emissive");
		if( !props.textureWrap )
			Reflect.deleteField(props,"textureWrap");
		if( !props.enableStencil ) {
			Reflect.deleteField(props, "stencilWriteMask");
			Reflect.deleteField(props, "stencilReadMask");
			Reflect.deleteField(props, "stencilValue");
			Reflect.deleteField(props, "stencilFailOp");
			Reflect.deleteField(props, "depthFailOp");
			Reflect.deleteField(props, "stencilPassOp");
			Reflect.deleteField(props, "stencilCompare");
		}
		if( props.drawOrder == "0" )
			Reflect.deleteField(props,"drawOrder");
		if( props.depthWrite == Default )
		 	Reflect.deleteField(props, "depthWrite");
		if ( !props.depthPrepass )
			Reflect.deleteField(props, "depthPrepass");
		if ( !props.flipBackFaceNormal )
			Reflect.deleteField(props, "flipBackFaceNormal");
		if ( !props.ignoreCollide )
			Reflect.deleteField(props, "ignoreCollide");
		if ( props.parallaxSteps == h3d.shader.Parallax.MAX_LAYERS || props.parallaxSteps == 0 )
			Reflect.deleteField(props, "parallaxSteps");
		#end
	}

	override function refreshProps() {
		resetProps();
		var props : PbrProps = props;

		// Preset
		switch( props.mode ) {
		case PBR:
			// pass name set below (in set_blendMode)
		case Forward:
			mainPass.setPassName("forward");
		case BeforeTonemapping, BeforeTonemappingDecal:
			if ( props.mode == BeforeTonemappingDecal )
				mainPass.setPassName("beforeTonemappingDecal");
			else
				mainPass.setPassName("beforeTonemapping");
			var gc = mainPass.getShader(h3d.shader.pbr.GammaCorrect);
			if( gc == null ) {
				gc = new h3d.shader.pbr.GammaCorrect();
				gc.useEmissiveHDR = true;
				gc.setPriority(-1);
				mainPass.addShader(gc);
			}
		case AfterTonemapping:
			mainPass.setPassName("afterTonemapping");
		case AfterTonemappingDecal:
			mainPass.setPassName("afterTonemappingDecal");
		case Distortion:
			mainPass.setPassName("distortion");
			mainPass.depthWrite = false;
		case Overlay:
			mainPass.setPassName("overlay");
		case Decal:
			mainPass.setPassName("decal");
			var vd = mainPass.getShader(h3d.shader.VolumeDecal);
			if( vd == null ) {
				vd = new h3d.shader.VolumeDecal(1,1);
				vd.setPriority(-1);
				mainPass.addShader(vd);
			}
			var sv = mainPass.getShader(h3d.shader.pbr.StrengthValues);
			if( sv == null ) {
				sv = new h3d.shader.pbr.StrengthValues();
				mainPass.addShader(sv);
			}
		case DecalPass:
			mainPass.setPassName("decal");
			var sv = mainPass.getShader(h3d.shader.pbr.StrengthValues);
			if( sv == null ) {
				sv = new h3d.shader.pbr.StrengthValues();
				mainPass.addShader(sv);
			}
		case TerrainPass:
			mainPass.setPassName("terrain");
		}

		// Blend modes
		switch( props.blend ) {
		case None: this.blendMode = None;
		case Alpha: this.blendMode = Alpha;
		case Add: this.blendMode = Add;
		case AlphaAdd: this.blendMode = AlphaAdd;
		case Multiply: this.blendMode = Multiply;
		case AlphaMultiply: this.blendMode = AlphaMultiply;
		}

		// Enable/Disable AlphaKill
		var tshader = textureShader;
		if( tshader != null ) {
			tshader.killAlpha = props.alphaKill;
			tshader.killAlphaThreshold = 0.5;
		}

		if( props.textureWrap ) {
			var t = texture;
			if( t != null ) t.wrap = Repeat;
			t = specularTexture;
			if( t != null ) t.wrap = Repeat;
			t = normalMap;
			if( t != null ) t.wrap = Repeat;
		}

		mainPass.culling = props.culling != null ? switch props.culling {
			case None: None;
			case Back: Back;
			case Front: Front;
			case Both: Both;
		} : Back;

		shadows = props.shadows;
		if( shadows ) getPass("shadow").culling = mainPass.culling;

		mainPass.depthTest = switch (props.depthTest) {
			case Less: Less;
			case LessEqual: LessEqual;
			case Greater: Greater;
			case GreaterEqual: GreaterEqual;
			case Always: Always;
			case Never: Never;
			case Equal: Equal;
			case NotEqual : NotEqual;
			default: Less;
		}

		if(props.depthWrite != null && props.depthWrite != Default)
		 	mainPass.depthWrite = props.depthWrite == On;

		// Get values from specular texture
		var emit = props.emissive == null ? 0 : props.emissive;
		var tex = mainPass.getShader(h3d.shader.pbr.PropsTexture);
		var def = mainPass.getShader(h3d.shader.pbr.PropsValues);
		if( tex == null && def == null ) {
			def = new h3d.shader.pbr.PropsValues();
			mainPass.addShader(def);
		}

		// we should have either one or other
		if( tex != null ) tex.emissiveValue = emit;
		if( def != null ) def.emissiveValue = emit;

		// Parallax
		var ps = mainPass.getShader(h3d.shader.Parallax);
		if( props.parallax > 0 ) {
			if( ps == null ) {
				ps = new h3d.shader.Parallax();
				mainPass.addShader(ps);
			}
			if ( props.parallaxSteps != null )
				ps.maxLayers = props.parallaxSteps;
			else
				ps.maxLayers = h3d.shader.Parallax.MAX_LAYERS;
			ps.amount = props.parallax;
			ps.heightMap = specularTexture;
			ps.heightMapChannel = A;
		} else if( ps != null )
			mainPass.removeShader(ps);

		setColorMask();

		setStencil();

		var p = passes;
		while ( p != null ) {
			if ( props.drawOrder == null )
				mainPass.layer = 0;
			else
				mainPass.layer = Std.parseInt(props.drawOrder);
			p = p.nextPass;
		}

		if ( props.depthPrepass ) {
			var passName = switch (props.mode) {
			case PBR:
				"depthPrepass";
			case BeforeTonemapping:
				"beforeTonemappingDepthPrepass";
			default:
				null;
			}
			if ( passName != null ) {
				mainPass.depthTest = switch ( mainPass.depthTest ) {
				case Less:
					LessEqual;
				case Greater:
					GreaterEqual;
				default:
					mainPass.depthTest;
				}

				var p = allocPass(passName);
				var killAlpha = new h3d.shader.KillAlpha();
				killAlpha.threshold = 0.5;
				p.addShader(killAlpha);
				p.depthWrite = true;
				p.depthTest = Less;
				p.culling = mainPass.culling;
				p.setBlendMode(None);
			}
		}

		var sh = mainPass.getShader(h3d.shader.FlipBackFaceNormal);
		if ( props.flipBackFaceNormal && sh == null )
			mainPass.addShader(new h3d.shader.FlipBackFaceNormal());
		else if ( !props.flipBackFaceNormal && sh != null )
			mainPass.removeShader(sh);
	}

	function setColorMask() {
		var props : PbrProps = props;
		mainPass.setColorMask(	props.colorMask & (1<<0) > 0 ? true : false,
								props.colorMask & (1<<1) > 0 ? true : false,
								props.colorMask & (1<<2) > 0 ? true : false,
								props.colorMask & (1<<3) > 0 ? true : false);
	}

	function setStencil() {
		var props : PbrProps = props;
		if( props.enableStencil ) {

			if( props.stencilFailOp == null ) props.stencilFailOp = Keep;
			if( props.depthFailOp == null ) props.depthFailOp = Keep;
			if( props.stencilPassOp == null ) props.stencilPassOp = Replace;
			if( props.stencilCompare == null ) props.stencilCompare = Always;
			if( props.stencilValue == null ) props.stencilValue = 0;
			if( props.stencilReadMask == null ) props.stencilReadMask = 0;
			if( props.stencilWriteMask == null ) props.stencilWriteMask = 0;

			inline function getStencilOp( op : PbrStencilOp ) : Data.StencilOp {
				return switch op {
					case Keep:Keep;
					case Zero:Zero;
					case Replace:Replace;
					case Increment:Increment;
					case IncrementWrap:IncrementWrap;
					case Decrement:Decrement;
					case DecrementWrap:DecrementWrap;
					case Invert:Invert;
				}
			}

			inline function getStencilCompare( op : PbrStencilCompare ) : Data.Compare {
				return switch op {
					case Always:Always;
					case Never:Never;
					case Equal:Equal;
					case NotEqual:NotEqual;
					case Greater:Greater;
					case GreaterEqual:GreaterEqual;
					case Less:Less;
					case LessEqual:LessEqual;
				}
			}

			var s = new Stencil();
			s.setFunc(getStencilCompare(props.stencilCompare), props.stencilValue, props.stencilReadMask, props.stencilWriteMask);
			s.setOp(getStencilOp(props.stencilFailOp), getStencilOp(props.depthFailOp), getStencilOp(props.stencilPassOp));
			mainPass.stencil = s;
		}
		else {
			mainPass.stencil = null;
		}
	}

	override function get_specularTexture() {
		var spec = mainPass.getShader(h3d.shader.pbr.PropsTexture);
		return spec == null ? null : spec.texture;
	}

	override function set_specularTexture(t) {
		if( specularTexture == t )
			return t;
		var props : PbrProps = props;
		var emit = props == null || props.emissive == null ? 0 : props.emissive;
		var spec = mainPass.getShader(h3d.shader.pbr.PropsTexture);
		var def = mainPass.getShader(h3d.shader.pbr.PropsValues);
		if( t != null ) {
			if( spec == null ) {
				spec = new h3d.shader.pbr.PropsTexture();
				spec.emissiveValue = emit;
				mainPass.addShader(spec);
			}
			spec.texture = t;
			if( def != null )
				mainPass.removeShader(def);
		} else {
			mainPass.removeShader(spec);
			// default values (if no texture)
			if( def == null ) {
				def = new h3d.shader.pbr.PropsValues();
				def.emissiveValue = emit;
				mainPass.addShader(def);
			}
		}


		// parallax
		var ps = mainPass.getShader(h3d.shader.Parallax);
		if( ps != null ) {
			ps.heightMap = t;
			ps.heightMapChannel = A;
			mainPass.removeShader(ps);
			mainPass.addShader(ps);
		}

		return t;
	}

	override function clone( ?m : BaseMaterial ) : BaseMaterial {
		var m = m == null ? new PbrMaterial() : cast m;
		super.clone(m);
		return m;
	}

	#if (editor && js)
	override function editProps() {
		var props : PbrProps = props;
		var layers : Array< { name : String, value : Int }> = hide.Ide.inst.currentConfig.get("material.drawOrder", []);
		return new js.jquery.JQuery('
			<dl>
				<dt>Mode</dt>
				<dd>
					<select field="mode">
						<option value="PBR">PBR</option>
						<option value="Forward">Forward PBR</option>
						<option value="BeforeTonemapping">Before Tonemapping</option>
						<option value="BeforeTonemappingDecal">Before Tonemapping Decal</option>
						<option value="AfterTonemapping">After Tonemapping</option>
						<option value="AfterTonemappingDecal">After Tonemapping Decal</option>
						<option value="Overlay">Overlay</option>
						<option value="Distortion">Distortion</option>
						<option value="Decal">Decal</option>
						<option value="DecalPass">DecalPass</option>
						<option value="TerrainPass">TerrainPass</option>
					</select>
				</dd>
				<dt>Blend</dt>
				<dd>
					<select field="blend">
						<option value="None">None</option>
						<option value="Alpha">Alpha</option>
						<option value="Add">Add</option>
						<option value="AlphaAdd">AlphaAdd</option>
						<option value="Multiply">Multiply</option>
						<option value="AlphaMultiply">AlphaMultiply</option>
					</select>
				</dd>
				<dt>Depth Test</dt>
				<dd>
					<select field="depthTest">
						<option value="Less">Less</option>
						<option value="LessEqual">LessEqual</option>
						<option value="Greater">Greater</option>
						<option value="GreaterEqual">GreaterEqual</option>
						<option value="Always">Always</option>
						<option value="Never">Never</option>
						<option value="Equal">Equal</option>
						<option value="NotEqual">NotEqual</option>
					</select>
				</dd>
				<dt>Depth Write</dt>
				<dd>
					<select field="depthWrite">
						<option value="" selected disabled hidden>Default</option>
						<option value="Default">Default</option>
						<option value="On">On</option>
						<option value="Off">Off</option>
					</select>
				</dd>
				<dt>Emissive</dt><dd><input type="range" min="0" max="10" field="emissive"/></dd>
				<dt>Parallax</dt><dd><input type="range" min="0" max="1" field="parallax"/></dd>
				<dt>Parallax steps</dt><dd><input type="range" min="0" max="255" step="1" field="parallaxSteps"/></dd>
				<dt>Shadows</dt><dd><input type="checkbox" field="shadows"/></dd>
				<dt>Culling</dt>
				<dd>
					<select field="culling">
						<option value="None">None</option>
						<option value="Back">Back</option>
						<option value="Front">Front</option>
						<option value="Both">Both</option>
					</select>
				</dd>
				<dt>AlphaKill</dt><dd><input type="checkbox" field="alphaKill"/></dd>
				<dt>Wrap</dt><dd><input type="checkbox" field="textureWrap"/></dd>
				<dt>Draw Order</dt>
				<dd>
					<select field="drawOrder">
						<option value="" selected disabled hidden>Default</option>
						${[for( i in 0...layers.length ) '<option value="${layers[i].value}">${layers[i].name}</option>'].join("")}
					</select>
				</dd>
				<dt>Depth prepass</dt><dd><input type="checkbox" field="depthPrepass"/></dd>
				<dt>Flip back face normal</dt><dd><input type="checkbox" field="flipBackFaceNormal"/></dd>
				<dt>Ignore collide</dt><dd><input type="checkbox" field="ignoreCollide"/></dd>
			</dl>
		');
	}
	#end

}