/* Shared timing-display rules. Actual lap times and positions are never changed. */
(function(root){
  'use strict';
  // Red requires a meaningful session improvement and a reasonable average
  // sector speed; the first sector is a baseline, not an automatic record.
  function sectorColor(seconds,personalBest,sessionBest,sectorMetres){
    if(!Number.isFinite(seconds)||seconds<=0||!Number.isFinite(sectorMetres)||sectorMetres<=0)return 'slow';
    var red=Number.isFinite(sessionBest)&&sessionBest>0&&seconds<=sessionBest*.98&&sectorMetres/seconds>=80/3.6;
    if(red)return 'record';
    if(Number.isFinite(personalBest)&&personalBest>0&&seconds<personalBest)return 'best';
    return 'slow';
  }
  if(typeof module!=='undefined'&&module.exports)module.exports=sectorColor;
  if(root)root.WMCSectorColor=sectorColor;
})(typeof window!=='undefined'?window:null);
