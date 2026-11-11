/* Shared bike contact in ground plane. The Ducati including rider is about
   2.4m long and 0.86m wide at the game's 1.15 visual scale. An oriented
   capsule follows each bike's heading, unlike a large circular hit bubble. */
(function(root){
'use strict';
var RADIUS=.43,HALF_LENGTH=.78,WIDTH=RADIUS*2;
function clamp(v,a,b){return Math.max(a,Math.min(b,v))}
function closest(a,b,ax,az,bx,bz){
  var afx=Math.sin(a.h),afz=Math.cos(a.h),bfx=Math.sin(b.h),bfz=Math.cos(b.h);
  var a0x=ax-afx*HALF_LENGTH,a0z=az-afz*HALF_LENGTH,a1x=ax+afx*HALF_LENGTH,a1z=az+afz*HALF_LENGTH;
  var b0x=bx-bfx*HALF_LENGTH,b0z=bz-bfz*HALF_LENGTH,b1x=bx+bfx*HALF_LENGTH,b1z=bz+bfz*HALF_LENGTH;
  var ux=a1x-a0x,uz=a1z-a0z,vx=b1x-b0x,vz=b1z-b0z,rx=a0x-b0x,rz=a0z-b0z;
  var aa=ux*ux+uz*uz,bb=ux*vx+uz*vz,cc=vx*vx+vz*vz,dd=ux*rx+uz*rz,ee=vx*rx+vz*rz,den=aa*cc-bb*bb;
  // Closest points on two finite line segments, including parallel bikes.
  var s=den>1e-10?clamp((bb*ee-cc*dd)/den,0,1):0;
  var t=(bb*s+ee)/cc;
  if(t<0){t=0;s=clamp(-dd/aa,0,1)}else if(t>1){t=1;s=clamp((bb-dd)/aa,0,1)}
  var dx=b0x+vx*t-(a0x+ux*s),dz=b0z+vz*t-(a0z+uz*s),d=Math.hypot(dx,dz);
  var nx,nz;if(d>1e-8){nx=dx/d;nz=dz/d}else{dx=bx-ax;dz=bz-az;var center=Math.hypot(dx,dz);if(center>1e-8){nx=dx/center;nz=dz/center}else{nx=afz;nz=-afx}}
  return {distance:d,nx:nx,nz:nz};
}
function resolve(a,b,pa,pb,dt,suppressImpulse){
  var ax=a.x-pa.x,az=a.z-pa.z,bx=b.x-pb.x,bz=b.z-pb.z,dx=bx-ax,dz=bz-az,travel=Math.hypot(dx,dz);
  // A conservative swept-circle broad phase avoids expensive narrow phase for
  // distant riders, including when they move quickly between physics ticks.
  var sx=pb.x-pa.x,sz=pb.z-pa.z,r2=travel*travel,q=r2?clamp(-(sx*dx+sz*dz)/r2,0,1):0;
  if(Math.hypot(sx+dx*q,sz+dz*q)>2*(HALF_LENGTH+RADIUS)+.001)return false;
  function at(t){return closest(a,b,pa.x+ax*t,pa.z+az*t,pb.x+bx*t,pb.z+bz*t)}
  var start=at(0),end=at(1),t=null,hitPoint=null;
  if(start.distance<=WIDTH){
    // Rewind only if still approaching. A bike moving away must not get stuck.
    if(dx*start.nx+dz*start.nz< -1e-8){t=0;hitPoint=start}
    else if(end.distance>=WIDTH)return false;
  }else if(travel>1e-9){
    // Distance between translating segments is Lipschitz-bounded by relative
    // travel. Conservative advancement catches fast crossings without tunnelling.
    var u=0;for(var i=0;i<80&&u<=1;i++){
      var p=at(u),gap=p.distance-WIDTH;
      if(gap<=.00001){t=u;hitPoint=p;break}
      u+=Math.max(.0000001,gap/travel*.9);
    }
  }
  if(t===null&&end.distance>=WIDTH)return false;
  var oldA=a.v,oldB=b.v;
  if(t!==null){a.x=pa.x+ax*t;a.z=pa.z+az*t;b.x=pb.x+bx*t;b.z=pb.z+bz*t}
  var contact=hitPoint||end,nx=contact.nx,nz=contact.nz;
  var afx=Math.sin(a.h),afz=Math.cos(a.h),bfx=Math.sin(b.h),bfz=Math.cos(b.h);
  var extent=WIDTH+HALF_LENGTH*(Math.abs(afx*nx+afz*nz)+Math.abs(bfx*nx+bfz*nz));
  var separation=(b.x-a.x)*nx+(b.z-a.z)*nz,shift=Math.max(0,extent-separation)/2;
  a.x-=nx*shift;a.z-=nz*shift;b.x+=nx*shift;b.z+=nz*shift;
  var avx=afx*a.v+(a.pushX||0),avz=afz*a.v+(a.pushZ||0),bvx=bfx*b.v+(b.pushX||0),bvz=bfz*b.v+(b.pushZ||0);
  var closing=(avx-bvx)*nx+(avz-bvz)*nz,hit=closing>.5&&!suppressImpulse;
  if(hit){
    var impulse=Math.min(closing*.55,12);
    function apply(s,fx,fz,ix,iz){var forward=ix*fx+iz*fz;s.v=Math.max(s.v>=0?0:-9,Math.min(88,s.v+forward));s.pushX=(s.pushX||0)+ix-forward*fx;s.pushZ=(s.pushZ||0)+iz-forward*fz;var side=Math.hypot(s.pushX,s.pushZ);if(side>20){s.pushX*=20/side;s.pushZ*=20/side}}
    apply(a,afx,afz,-nx*impulse,-nz*impulse);apply(b,bfx,bfz,nx*impulse,nz*impulse);
  }
  if(t!==null){
    var ar=Math.abs(oldA)>1e-8?Math.min(1,Math.abs(a.v/oldA)):1,br=Math.abs(oldB)>1e-8?Math.min(1,Math.abs(b.v/oldB)):1;
    if(Number.isFinite(dt)&&dt>0){var rest=dt*(1-t);a.x+=(afx*a.v+(a.pushX||0))*rest;a.z+=(afz*a.v+(a.pushZ||0))*rest;b.x+=(bfx*b.v+(b.pushX||0))*rest;b.z+=(bfz*b.v+(b.pushZ||0))*rest}
    else{a.x+=ax*(1-t)*ar;a.z+=az*(1-t)*ar;b.x+=bx*(1-t)*br;b.z+=bz*(1-t)*br}
    // Do not allow the remaining movement to cross the original contact plane.
    var along=(b.x-a.x)*nx+(b.z-a.z)*nz;
    if(along<extent){var correction=(extent-along)/2;a.x-=nx*correction;a.z-=nz*correction;b.x+=nx*correction;b.z+=nz*correction}
  }
  return hit;
}
var api={resolve:resolve,width:WIDTH,length:2*(HALF_LENGTH+RADIUS),distance:function(a,b){return closest(a,b,a.x,a.z,b.x,b.z).distance}};root.WMCBikeContact=api;if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window!=='undefined'?window:globalThis);
