/* Shared, authoritative bike contact. Positions are swept each physics tick
   so fast riders cannot tunnel through one another between updates. */
(function(root){
'use strict';
var DIAMETER=2.2;
function resolve(a,b,pa,pb,dt,suppressImpulse){
  var ax=a.x-pa.x,az=a.z-pa.z,bx=b.x-pb.x,bz=b.z-pb.z,oldA=a.v,oldB=b.v;
  var sx=pb.x-pa.x,sz=pb.z-pa.z,dx=bx-ax,dz=bz-az;
  var endX=b.x-a.x,endZ=b.z-a.z,end2=endX*endX+endZ*endZ,r2=DIAMETER*DIAMETER,t=null;
  var c=sx*sx+sz*sz-r2,A=dx*dx+dz*dz,B=2*(sx*dx+sz*dz);
  if(c<=0&&B<0)t=0;
  if(c>0&&A>1e-12){var disc=B*B-4*A*c;if(disc>=0){var hit=(-B-Math.sqrt(disc))/(2*A);if(hit>=0&&hit<=1)t=hit}}
  if(t===null&&end2>=r2)return false;
  // Rewind a swept impact to its first contact, never to the far side.
  if(t!==null){a.x=pa.x+(a.x-pa.x)*t;a.z=pa.z+(a.z-pa.z)*t;b.x=pb.x+(b.x-pb.x)*t;b.z=pb.z+(b.z-pb.z)*t;endX=b.x-a.x;endZ=b.z-a.z}
  var d=Math.hypot(endX,endZ),nx=d>1e-8?endX/d:Math.sin(a.h),nz=d>1e-8?endZ/d:Math.cos(a.h);
  var shift=Math.max(0,DIAMETER-d)/2;a.x-=nx*shift;a.z-=nz*shift;b.x+=nx*shift;b.z+=nz*shift;
  var afx=Math.sin(a.h),afz=Math.cos(a.h),bfx=Math.sin(b.h),bfz=Math.cos(b.h);
  var avx=afx*a.v+(a.pushX||0),avz=afz*a.v+(a.pushZ||0),bvx=bfx*b.v+(b.pushX||0),bvz=bfz*b.v+(b.pushZ||0);
  var closing=(avx-bvx)*nx+(avz-bvz)*nz,hit=closing>.5&&!suppressImpulse;
  if(hit){
    // Equal-mass impact with a little bounce: transfer momentum to the bike
    // being hit, retaining sideways motion separately from engine speed.
    var impulse=Math.min(closing*.55,12);
    function apply(s,fx,fz,ix,iz){
      var forward=ix*fx+iz*fz;s.v=Math.max(s.v>=0?0:-9,Math.min(88,s.v+forward));
      s.pushX=(s.pushX||0)+ix-forward*fx;s.pushZ=(s.pushZ||0)+iz-forward*fz;
      var side=Math.hypot(s.pushX,s.pushZ);if(side>20){s.pushX*=20/side;s.pushZ*=20/side}
    }
    apply(a,afx,afz,-nx*impulse,-nz*impulse);apply(b,bfx,bfz,nx*impulse,nz*impulse);
  }
  // Keep moving for the remainder of the step after the impact. Rewinding
  // both riders to contact every tick made close bikes freeze and stutter.
  if(t!==null){
    var ar=Math.abs(oldA)>1e-8?Math.min(1,Math.abs(a.v/oldA)):1,br=Math.abs(oldB)>1e-8?Math.min(1,Math.abs(b.v/oldB)):1;
    if(Number.isFinite(dt)&&dt>0){var rest=dt*(1-t);a.x+=(afx*a.v+(a.pushX||0))*rest;a.z+=(afz*a.v+(a.pushZ||0))*rest;b.x+=(bfx*b.v+(b.pushX||0))*rest;b.z+=(bfz*b.v+(b.pushZ||0))*rest}
    else{a.x+=ax*(1-t)*ar;a.z+=az*(1-t)*ar;b.x+=bx*(1-t)*br;b.z+=bz*(1-t)*br}
    var rx=b.x-a.x,rz=b.z-a.z,along=rx*nx+rz*nz;
    // Enforce the original contact plane; Euclidean distance alone would
    // allow a fast bike to emerge on the far side during this same step.
    if(along<DIAMETER){var correction=(DIAMETER-along)/2;a.x-=nx*correction;a.z-=nz*correction;b.x+=nx*correction;b.z+=nz*correction}
  }
  return hit;
}
var api={resolve:resolve,diameter:DIAMETER};root.WMCBikeContact=api;if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window!=='undefined'?window:globalThis);
