// Cluster analysis helpers

struct ClusterResult
{
   bool  member_mask[];
   PRZ   zones[];
   int   zone_count;
   int   visible_candidates;

   void Clear()
   {
      ArrayResize(member_mask, 0);
      ArrayResize(zones, 0);
      zone_count = 0;
      visible_candidates = 0;
   }
};

class ClusterManager
{
public:
   struct Config
   {
      double cluster_range;
      int    min_lines;
      int    max_visible_lines;
      ENUM_PRICE_LINE_TRIM_MODE trim_mode;
      double ref_price;
      bool   ref_price_valid;

      Config()
      {
         cluster_range = 0.0;
         min_lines = 0;
         max_visible_lines = 0;
         trim_mode = PRICE_LINE_TRIM_OLDEST;
         ref_price = 0.0;
         ref_price_valid = false;
      }
   };

   ClusterManager(){ m_result.Clear(); }

   bool Analyze(const FibItem &all[], int all_total,
                const int &view_idx[], int view_count,
                const Config &cfg)
   {
      m_result.Clear();
      ArrayResize(m_result.member_mask, all_total);
      for(int i=0;i<all_total;i++) m_result.member_mask[i]=false;

      if(view_count<=0 || all_total<=0)
         return false;
      if(cfg.cluster_range<=0.0 || cfg.min_lines<=1)
         return false;

      SortPricesWithIndex(all, view_idx, view_count);
      ComputeClusterMembershipAndZones(all, view_count,
                                       cfg.cluster_range,
                                       cfg.min_lines,
                                       cfg.cluster_range);

      if(cfg.max_visible_lines>0)
      {
         int clusterFibIdx[];
         for(int k=0;k<view_count;k++)
         {
            int idx=view_idx[k];
            if(idx<0 || idx>=all_total) continue;
            if(!m_result.member_mask[idx]) continue;
            int s = ArraySize(clusterFibIdx);
            ArrayResize(clusterFibIdx, s+1);
            clusterFibIdx[s]=idx;
         }
         if(ArraySize(clusterFibIdx) > cfg.max_visible_lines)
         {
            EnforceMaxLineLimit(clusterFibIdx, all, cfg.max_visible_lines, cfg.trim_mode,
                                cfg.ref_price, cfg.ref_price_valid);
            bool keep[];
            ArrayResize(keep, all_total);
            for(int i=0;i<all_total;i++) keep[i]=false;
            for(int i=0;i<ArraySize(clusterFibIdx);i++)
            {
               int idx = clusterFibIdx[i];
               if(idx>=0 && idx<all_total) keep[idx]=true;
            }
            for(int i=0;i<all_total;i++)
               m_result.member_mask[i] = m_result.member_mask[i] && keep[i];
         }
      }

      int visible=0;
      for(int k=0;k<view_count;k++)
      {
         int idx=view_idx[k];
         if(idx<0 || idx>=all_total) continue;
         if(m_result.member_mask[idx]) visible++;
      }
      m_result.visible_candidates = visible;
      m_result.zone_count = ArraySize(m_result.zones);
      return (visible>0);
   }

   ClusterResult Result() const { return m_result; }

private:
   ClusterResult m_result;
   double        m_sorted_prices[];
   int           m_sorted_indices[];

   void SortPricesWithIndex(const FibItem &all[], const int &view_idx[], int n)
   {
      ArrayResize(m_sorted_prices, n);
      ArrayResize(m_sorted_indices, n);
      for(int k=0;k<n;k++){
         int idx=view_idx[k];
         m_sorted_indices[k]=idx;
         m_sorted_prices[k]=(idx>=0 && idx<ArraySize(all) ? all[idx].price : 0.0);
      }
      for(int a=0;a<n-1;a++){
         int best=a;
         for(int b=a+1;b<n;b++) if(m_sorted_prices[b]<m_sorted_prices[best]) best=b;
         if(best!=a){
            double tp=m_sorted_prices[a]; m_sorted_prices[a]=m_sorted_prices[best]; m_sorted_prices[best]=tp;
            int ti=m_sorted_indices[a]; m_sorted_indices[a]=m_sorted_indices[best]; m_sorted_indices[best]=ti;
         }
      }
   }

   void ComputeClusterMembershipAndZones(const FibItem &all[],
                                         int view_count,
                                         double range,
                                         int min_lines,
                                         double rect_thickness)
   {
      ArrayResize(m_result.zones, 0);
      m_result.zone_count = 0;
      if(view_count<=0 || range<=0.0 || min_lines<=1) return;

      const double h = range*0.5;
      double tol = LabelManager::PriceTolerance();
      if(tol<=0.0) tol = 1e-8;

      double bucketPrice[];
      int bucketStart[];
      int bucketLen[];
      ArrayResize(bucketPrice, view_count);
      ArrayResize(bucketStart, view_count);
      ArrayResize(bucketLen, view_count);

      int bucketCount=0;
      int idx=0;
      while(idx<view_count)
      {
         double base = m_sorted_prices[idx];
         int start = idx;
         int len = 1;
         idx++;
         while(idx<view_count && MathAbs(m_sorted_prices[idx]-base) <= tol){
            len++;
            idx++;
         }
         bucketPrice[bucketCount] = base;
         bucketStart[bucketCount] = start;
         bucketLen[bucketCount]   = len;
         bucketCount++;
      }
      ArrayResize(bucketPrice, bucketCount);
      ArrayResize(bucketStart, bucketCount);
      ArrayResize(bucketLen, bucketCount);
      if(bucketCount==0) return;

      struct Cand {
         double low, high, center;
         int unique_cnt;
         int total_cnt;
      };
      Cand cand[]; ArrayResize(cand,0);

      for(int anchor=0; anchor<bucketCount; ++anchor)
      {
         double center = bucketPrice[anchor];
         double L = center - h;
         double R = center + h;
         int s = LowerBound(bucketPrice, bucketCount, L - tol);
         int e = UpperBound(bucketPrice, bucketCount, R + tol);
         ClusterLegPick picks[]; ArrayResize(picks,0);
         int totalCnt = 0;
         double clusterLow = m_sorted_prices[bucketStart[s]];
         double clusterHigh = m_sorted_prices[bucketStart[e-1] + bucketLen[e-1]-1];

         for(int bucket=s; bucket<e; ++bucket)
         {
            int startIdx = bucketStart[bucket];
            int len = bucketLen[bucket];
            for(int k=0;k<len;k++){
               int all_idx = m_sorted_indices[startIdx + k];
               if(all_idx<0 || all_idx>=ArraySize(m_result.member_mask)) continue;
               totalCnt++;
               int legId = all[all_idx].leg_id;
               double dist = MathAbs(all[all_idx].price - center);
               int slot=-1;
               for(int m=0;m<ArraySize(picks);m++){
                  if(picks[m].leg_id==legId){ slot=m; break; }
               }
               if(slot==-1){
                  int sz = ArraySize(picks);
                  ArrayResize(picks, sz+1);
                  picks[sz].leg_id = legId;
                  picks[sz].fib_idx = all_idx;
                  picks[sz].dist_center = dist;
               }else if(dist < picks[slot].dist_center){
                  picks[slot].fib_idx = all_idx;
                  picks[slot].dist_center = dist;
               }
            }
         }
         int uniqueCnt = ArraySize(picks);
         if(uniqueCnt < min_lines) continue;

         for(int m=0;m<uniqueCnt;m++){
            int all_idx = picks[m].fib_idx;
            if(all_idx>=0 && all_idx<ArraySize(m_result.member_mask)) m_result.member_mask[all_idx]=true;
         }

         int ci = ArraySize(cand)+1;
         ArrayResize(cand, ci);
         cand[ci-1].low = clusterLow;
         cand[ci-1].high = clusterHigh;
         cand[ci-1].center = 0.5*(clusterLow+clusterHigh);
         cand[ci-1].unique_cnt = uniqueCnt;
         cand[ci-1].total_cnt = totalCnt;
      }

      if(ArraySize(cand)==0)
         return;

      for(int a=0;a<ArraySize(cand)-1;a++){
         int best=a;
         for(int b=a+1;b<ArraySize(cand);b++) if(cand[b].low < cand[best].low) best=b;
         if(best!=a){ Cand t=cand[a]; cand[a]=cand[best]; cand[best]=t; }
      }

      bool open=false; Cand best;
      for(int i=0;i<ArraySize(cand);i++){
         if(!open){ best=cand[i]; open=true; continue; }
         bool overlap = !(cand[i].low > best.high || cand[i].high < best.low);
         if(overlap){
            bool takeNew=false;
            if(cand[i].unique_cnt > best.unique_cnt) takeNew=true;
            else if(cand[i].unique_cnt == best.unique_cnt && cand[i].total_cnt > best.total_cnt) takeNew=true;
            if(takeNew) best=cand[i];
         }else{
            double span = MathMax(0.0, best.high - best.low);
            double targetWidth = (rect_thickness>0.0 ? MathMax(rect_thickness, span) : MathMax(range, span));
            double pad = (targetWidth > span ? 0.5*(targetWidth - span) : 0.0);
            PRZ z;
            z.low = best.low - pad;
            z.high = best.high + pad;
            z.center = (z.low+z.high)*0.5;
            z.count = best.unique_cnt;
            int m=ArraySize(m_result.zones)+1; ArrayResize(m_result.zones,m); m_result.zones[m-1]=z;

            best=cand[i];
         }
      }
      if(open){
         double span = MathMax(0.0, best.high - best.low);
         double targetWidth = (rect_thickness>0.0 ? MathMax(rect_thickness, span) : MathMax(range, span));
         double pad = (targetWidth > span ? 0.5*(targetWidth - span) : 0.0);
         PRZ z;
         z.low = best.low - pad;
         z.high = best.high + pad;
         z.center = (z.low+z.high)*0.5;
         z.count = best.unique_cnt;
         int m=ArraySize(m_result.zones)+1; ArrayResize(m_result.zones,m); m_result.zones[m-1]=z;
      }
      m_result.zone_count = ArraySize(m_result.zones);
   }
};
