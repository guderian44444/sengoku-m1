shader_type canvas_item;
render_mode blend_mix, unshaded;
// Optional production Sprite2D path. Set age_seconds from authoritative action tick,
// not TIME, so hitstop/pause/replay remain deterministic. Same texture on back/front nodes.
uniform float age_seconds = 0.0;
uniform float opacity : hint_range(0.0,1.0) = 1.0;
uniform bool split_depth = false;
uniform bool front_pass = true;
uniform float seam : hint_range(0.0,1.0) = 0.518;
uniform bool ellipse_flow = false;
uniform vec2 flow_center = vec2(0.5,0.518);
uniform vec2 flow_radius = vec2(0.46,0.18);
uniform float angular_speed = 0.6;
uniform float turbulence : hint_range(0.0,0.02) = 0.008;
uniform float render_padding = 0.0;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
 vec2 logical_uv = UV*(1.0+2.0*render_padding)-vec2(render_padding);
 vec2 uv = logical_uv;
 if (split_depth && ((front_pass && logical_uv.y < seam) || (!front_pass && logical_uv.y >= seam))) discard;
 if (ellipse_flow) {
  vec2 q = (uv-flow_center)/flow_radius;
  float a = age_seconds*angular_speed;
  uv = flow_center + vec2(q.x*cos(a)-q.y*sin(a),q.x*sin(a)+q.y*cos(a))*flow_radius;
 } else {
  uv += vec2(sin(uv.y*26.0-age_seconds*6.0),cos(uv.x*21.0-age_seconds*4.0))*turbulence*sin(uv.x*3.14159265)*sin(uv.y*3.14159265);
 }
 if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {COLOR=vec4(0.0);}
 else {COLOR=texture(TEXTURE,uv)*vertex_tint; COLOR.a*=opacity;}
}
