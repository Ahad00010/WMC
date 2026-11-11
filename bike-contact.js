/* Shared, authoritative bike contact. Positions are swept each physics tick
   so fast riders cannot tunnel through one another between updates. */
(function(root){
'use strict';
var DIAMETER=2.2;
function resolve(a,b,pa,pb){
  var sx=pb.x-pa.x,sz=pb.z-pa.z,dx=(b.x-a.x)-sx,dz=(b.z-a.z)-sz;
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
  var approachA=(afx*nx+afz*nz)*a.v,approachB=-(bfx*nx+bfz*nz)*b.v,closing=approachA+approachB;
  if(closing>.05){
    // Only reduce speed: no accidental boosts or reverse movement on impact.
    var loss=Math.min(closing*.45,25);
    var weightA=Math.max(0,approachA),weightB=Math.max(0,approachB),sum=weightA+weightB;
    if(sum>0){a.v=Math.sign(a.v)*Math.max(0,Math.abs(a.v)-loss*weightA/sum);b.v=Math.sign(b.v)*Math.max(0,Math.abs(b.v)-loss*weightB/sum)}
    return true;
  }
  return t!==null;
}
var api={resolve:resolve,diameter:DIAMETER};root.WMCBikeContact=api;if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window!=='undefined'?window:globalThis);
