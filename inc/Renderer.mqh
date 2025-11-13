// Rendering logic (price/time/debug)
#pragma once

extern FiboContext g_ctx;
extern ChartOverlayService g_overlay;

class Renderer
{
public:
   Renderer(){ ResetFrame(); }

   void PrepareFrame(const datetime &time[], int rates_total, bool series)
   {
      ResetFrame();
      if(rates_total<=0)
         return;

      datetime left  = time[series? rates_total-1 : 0];
      datetime right = time[series? 0 : rates_total-1];
      if(left>right){
         datetime tmp=left;
         left=right;
         right=tmp;
      }
      int ps = PeriodSeconds(); if(ps<=0) ps=60;
      long margin = (long)ps * (long)MathMax(0, InpRightTextMarginBars);
      right = (datetime)((long)right + margin);
      if(left==right){
         left  = (datetime)((long)left  - ps);
         right = (datetime)((long)right + ps);
      }
      m_label_left = left;
      m_label_right = right;
      m_has_label_bounds = true;
   }

   int RenderPriceRaw(const FibItem &items[], int total_items, const int &view_idx[],
                      LabelManager &labels)
   {
      g_overlay.ClearTrackedPriceLines();

      datetime labelLeft = LabelLeft();
      datetime labelRight = LabelRight();
      int lineWidth = MathMax(1, InpFibLineWidth);

      int drawn=0;
      int viewCount = ArraySize(view_idx);
      for(int k=0;k<viewCount;k++){
         int idx=view_idx[k];
         if(idx<0 || idx>=total_items) continue;
         const FibItem &item = items[idx];
         double priceToDraw = item.price;
         color col = (item.is_expansion ? InpExpandLineColor : InpRetraceLineColor);
         string ln = BuildPriceLineObjectName(item, drawn);
         g_overlay.UpsertPriceSegment(ln, 0, 0, priceToDraw, col, lineWidth);
         ObjectSetString(ChartID(), ln, OBJPROP_COMMENT, BuildPriceLineComment(item));
         g_overlay.RecordPriceLineName(ln);

         if(InpShowLabels){
            string lbl = BuildLineLabelText(item);
            string identBase = BuildPriceLabelIdentity(item);
            int slotIdx = labels.AcquireSlot(identBase);
            labels.MaintainPriceLabels(item, slotIdx, identBase, priceToDraw, lbl, col, labelLeft, labelRight);
         }
         drawn++;
      }
      return drawn;
   }

   int RenderPriceClusters(const FibItem &items[], int total_items, const int &view_idx[],
                           const ClusterResult &cluster,
                           LabelManager &labels)
   {
      g_overlay.ClearTrackedPriceLines();

      datetime labelLeft = LabelLeft();
      datetime labelRight = LabelRight();
      int lineWidth = MathMax(1, InpFibLineWidth);
      int viewCount = ArraySize(view_idx);
      int maskSize = ArraySize(cluster.member_mask);
      int drawn=0;

      for(int k=0;k<viewCount;k++){
         int idx=view_idx[k];
         if(idx<0 || idx>=total_items) continue;
         if(idx>=maskSize) continue;
         if(!cluster.member_mask[idx]) continue;

         const FibItem &item = items[idx];
         double priceToDraw = item.price;
         color col = (item.is_expansion ? InpExpandLineColor : InpRetraceLineColor);
         string ln = BuildPriceLineObjectName(item, drawn);
         g_overlay.UpsertPriceSegment(ln, 0, 0, priceToDraw, col, lineWidth);
         ObjectSetString(ChartID(), ln, OBJPROP_COMMENT, BuildPriceLineComment(item));
         g_overlay.RecordPriceLineName(ln);

         if(InpShowLabels){
            string lbl = BuildLineLabelText(item);
            string identBase = BuildPriceLabelIdentity(item);
            int slotIdx = labels.AcquireSlot(identBase);
            labels.MaintainPriceLabels(item, slotIdx, identBase, priceToDraw, lbl, col, labelLeft, labelRight);
         }
         drawn++;
      }
      return drawn;
   }

   void RenderTimeMarks(const FibItem &items[], const int &view_idx[], int view_count)
   {
      int drawn_dot=0, drawn_vl=0;
      for(int i=0;i<view_count;i++){
         int idx=view_idx[i];
         if(idx<0 || idx>=ArraySize(items)) continue;
         const FibItem &it = items[idx];
         string nm = G_PREF_TF + "DOT_" + IntegerToString(drawn_dot++);
         g_overlay.UpsertText(nm, it.t, it.price, ".", InpTimeDotColor, InpTimeDotFontSize);
         if(InpShowTimeVLines){
            string vl = G_PREF_TFVL + IntegerToString(drawn_vl++);
            g_overlay.UpsertVLine(vl, it.t, InpTimeDotColor, 1, true);
         }
      }
      for(int i=drawn_dot;i<g_ctx.prev_tf_count;i++) ObjectDelete(ChartID(), G_PREF_TF + "DOT_" + IntegerToString(i));
      for(int i=drawn_vl;i<g_ctx.prev_tfvl_count;i++) ObjectDelete(ChartID(), G_PREF_TFVL + IntegerToString(i));
      g_ctx.prev_tf_count   = drawn_dot;
      g_ctx.prev_tfvl_count = drawn_vl;
   }

   void RenderDebugOverlays(const LineItem &price_all[], int price_total,
                            const TimeItem &time_all[], int time_total,
                            const datetime &time[], int rates_total)
   {
      datetime labelTime = DebugLabelTime(time, rates_total);
      RenderDebugPriceSubset(price_all, price_total, false, InpDebugLastRetractions,
                             InpRetraceLineColor, labelTime,
                             G_PREF_DBG_RET, G_PREF_DBG_RET_LBL, g_ctx.prev_dbg_ret_count);
      RenderDebugPriceSubset(price_all, price_total, true, InpDebugLastExpansions,
                             InpExpandLineColor, labelTime,
                             G_PREF_DBG_EXP, G_PREF_DBG_EXP_LBL, g_ctx.prev_dbg_exp_count);
      RenderDebugTimeSubset(time_all, time_total, InpDebugLastTimeMarks,
                            G_PREF_DBG_TIME, G_PREF_DBG_TIME_VL,
                            g_ctx.prev_dbg_time_dot_count, g_ctx.prev_dbg_time_vl_count);
   }

private:
   datetime m_label_left;
   datetime m_label_right;
   bool     m_has_label_bounds;

   void ResetFrame()
   {
      m_label_left = 0;
      m_label_right = 0;
      m_has_label_bounds = false;
   }

   datetime LabelLeft() const
   {
      return (m_has_label_bounds ? m_label_left : 0);
   }

   datetime LabelRight() const
   {
      return (m_has_label_bounds ? m_label_right : TimeCurrent());
   }

   datetime DebugLabelTime(const datetime &time[], int rates_total) const
   {
      if(m_has_label_bounds)
         return m_label_right;
      if(rates_total>0){
         bool series = FiboUtils::IsSeries(time, rates_total);
         datetime right = time[series? 0 : rates_total-1];
         int ps = PeriodSeconds(); if(ps<=0) ps=60;
         long margin = (long)ps * (long)MathMax(0, InpRightTextMarginBars);
         return (datetime)((long)right + margin);
      }
      return TimeCurrent();
   }

   void RenderDebugPriceSubset(const LineItem &source[], int total, bool wantExpansion, int limit,
                               color lineColor, datetime labelTime,
                               const string &prefLine, const string &prefLabel, int &prevCount)
   {
      limit = MathMax(0, limit);
      if(limit==0 || total<=0){
         for(int i=0;i<prevCount;i++){
            ObjectDelete(ChartID(), prefLine + IntegerToString(i));
            ObjectDelete(ChartID(), prefLabel + IntegerToString(i));
         }
         prevCount=0;
         return;
      }

      int drawn=0;
      for(int i=0;i<total && drawn<limit;i++)
      {
         if(source[i].is_expansion != wantExpansion) continue;
         string nm = prefLine + IntegerToString(drawn);
         double priceToDraw = source[i].price;
         g_overlay.UpsertPriceSegment(nm, 0, 0, priceToDraw, lineColor, MathMax(1, InpFibLineWidth), STYLE_DASHDOTDOT);
         string lbl = prefLabel + IntegerToString(drawn);
         string text = StringFormat("DBG %s (leg %d)", RatioTag(source[i].ratio), source[i].leg_id);
         g_overlay.UpsertText(lbl, labelTime, priceToDraw, text, lineColor, 8);
         drawn++;
      }

      for(int i=drawn;i<prevCount;i++){
         ObjectDelete(ChartID(), prefLine + IntegerToString(i));
         ObjectDelete(ChartID(), prefLabel + IntegerToString(i));
      }
      prevCount=drawn;
   }

   void RenderDebugTimeSubset(const TimeItem &source[], int total, int limit,
                              const string &prefDot, const string &prefVLine,
                              int &prevDots, int &prevVLines)
   {
      limit = MathMax(0, limit);
      if(limit==0 || total<=0){
         for(int i=0;i<prevDots;i++) ObjectDelete(ChartID(), prefDot + IntegerToString(i));
         for(int i=0;i<prevVLines;i++) ObjectDelete(ChartID(), prefVLine + IntegerToString(i));
         prevDots=0;
         prevVLines=0;
         return;
      }

      int drawn=0;
      color dbgColor = clrLime;
      for(int i=0;i<total && drawn<limit;i++)
      {
         string nm = prefDot + IntegerToString(drawn);
         string text = StringFormat("DBG T %s %s", FiboUtils::FormatRatioUnit(source[i].ratio), (source[i].forward? "F" : "B"));
         g_overlay.UpsertText(nm, source[i].t, source[i].priceB, text, dbgColor, InpTimeDotFontSize);

         string vl = prefVLine + IntegerToString(drawn);
         g_overlay.UpsertVLine(vl, source[i].t, dbgColor, 1, true);
         drawn++;
      }

      for(int i=drawn;i<prevDots;i++) ObjectDelete(ChartID(), prefDot + IntegerToString(i));
      for(int i=drawn;i<prevVLines;i++) ObjectDelete(ChartID(), prefVLine + IntegerToString(i));
      prevDots = drawn;
      prevVLines = drawn;
   }
};
