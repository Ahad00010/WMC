// Use the same circuit control points, sampling, and Float32 rounding as the game.
// The web and server must be deployed from the same revision.
import {readFileSync} from 'node:fs';
import {CatmullRomCurve3, Vector3} from 'three';
const html=readFileSync(new URL('../../index.html',import.meta.url),'utf8');
const match=html.match(/var ctrl=(\[\[.*?\]\])\s*\.map\(function\(p\)/s);
if(!match)throw new Error('Unable to find game circuit control points');
const points=JSON.parse(match[1]);
if(points.length<4||!points.every(p=>p.length===2&&p.every(Number.isFinite)))throw new Error('Invalid game circuit');
const curve=new CatmullRomCurve3(points.map(([x,z])=>new Vector3(x,0,z)),true,'centripetal');
export const length=curve.getLength();
export const N=Math.round(length/5);
const pts=curve.getSpacedPoints(N);pts.pop();
export const px=new Float32Array(N),pz=new Float32Array(N),tx=new Float32Array(N),tz=new Float32Array(N),lx=new Float32Array(N),lz=new Float32Array(N);
for(let i=0;i<N;i++){
  px[i]=pts[i].x;pz[i]=pts[i].z;
  const a=pts[(i+1)%N],b=pts[(i-1+N)%N],dx=a.x-b.x,dz=a.z-b.z,l=Math.hypot(dx,dz);
  tx[i]=dx/l;tz[i]=dz/l;lx[i]=tz[i];lz[i]=-tx[i];
}
export const roadHalfWidth=i=>8+1.5*(1-Math.cos(2*Math.PI*i/N));
export const kerbEdge=i=>roadHalfWidth(i)+2.5;
export const wallEdge=i=>roadHalfWidth(i)+10;
