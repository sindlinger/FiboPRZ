// Chart overlay utilities (all Object* mutations)

extern FiboContext g_ctx;

class ChartOverlayService
{
public:
   void ClearByPrefix(const string &pref)
   {
      long cid=ChartID();
      int total=ObjectsTotal(cid,0,-1);
      int removed=0;
      for(int i=total-1;i>=0;--i){
         string nm=ObjectName(cid,i,0);
         if(StringFind(nm,pref)==0){
            ObjectDelete(cid,nm);
            removed++;
         }
      }
      Dbg(StringFormat("[Clear] prefix=%s removed=%d total=%d", pref, removed, total));
   }

   void UpsertTrend(const string &name,datetime t1,double p1,datetime t2,double p2,color col,int w)
   {
      long cid=ChartID();
      if(ObjectFind(cid,name)<0) ObjectCreate(cid,name,OBJ_TREND,0,t1,p1,t2,p2);
      else{ ObjectMove(cid,name,0,t1,p1); ObjectMove(cid,name,1,t2,p2); }
      ObjectSetInteger(cid,name,OBJPROP_COLOR,col);
      ObjectSetInteger(cid,name,OBJPROP_WIDTH,w);
      ObjectSetInteger(cid,name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(cid,name,OBJPROP_RAY,false);
      ObjectSetInteger(cid,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(cid,name,OBJPROP_BACK,false);
   }

   void UpsertPriceSegment(const string &name,datetime t1,datetime t2,double price,color col,int w,ENUM_LINE_STYLE style=STYLE_SOLID,bool back=false)
   {
      long cid=ChartID();
      if(ObjectFind(cid,name)<0) ObjectCreate(cid,name,OBJ_HLINE,0,0,price);
      else ObjectSetDouble(cid,name,OBJPROP_PRICE,price);
      ObjectSetInteger(cid,name,OBJPROP_COLOR,col);
      ObjectSetInteger(cid,name,OBJPROP_WIDTH,w);
      ObjectSetInteger(cid,name,OBJPROP_STYLE,style);
      ObjectSetInteger(cid,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(cid,name,OBJPROP_BACK,back);
   }

   void UpsertText(const string &name,datetime t,double price,const string &text,color col,int fontsize=8,ENUM_ANCHOR_POINT anchor=ANCHOR_LEFT)
   {
      long cid=ChartID();
      if(ObjectFind(cid,name)<0) ObjectCreate(cid,name,OBJ_TEXT,0,t,price);
      else ObjectMove(cid,name,0,t,price);
      ObjectSetString (cid,name,OBJPROP_TEXT,text);
      ObjectSetInteger(cid,name,OBJPROP_COLOR,col);
      ObjectSetInteger(cid,name,OBJPROP_FONTSIZE,fontsize);
      ObjectSetInteger(cid,name,OBJPROP_ANCHOR,anchor);
      ObjectSetInteger(cid,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(cid,name,OBJPROP_BACK,true);
   }

   void UpsertVLine(const string &name, datetime t, color col, int w, bool back=true)
   {
      long cid=ChartID();
      if(ObjectFind(cid,name)<0) ObjectCreate(cid,name,OBJ_VLINE,0,t,0);
      else ObjectMove(cid,name,0,t,0);
      ObjectSetInteger(cid,name,OBJPROP_COLOR,col);
      ObjectSetInteger(cid,name,OBJPROP_WIDTH,w);
      ObjectSetInteger(cid,name,OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(cid,name,OBJPROP_BACK, back);
      ObjectSetInteger(cid,name,OBJPROP_SELECTABLE,false);
   }

   void ClearTrackedPriceLines()
   {
      long cid = ChartID();
      for(int i=0;i<ArraySize(g_ctx.price_line_names);i++)
         ObjectDelete(cid, g_ctx.price_line_names[i]);
      ArrayResize(g_ctx.price_line_names,0);
   }

   void RecordPriceLineName(const string &name)
   {
      int n=ArraySize(g_ctx.price_line_names)+1;
      ArrayResize(g_ctx.price_line_names,n);
      g_ctx.price_line_names[n-1]=name;
   }

   void DrawZigZagOverlay(int handle,bool draw_lines,
                          const string &pref_lines,int &prev_line_count,
                          color line_col,int line_width,
                          const double &high[],const double &low[],const datetime &time[],
                          int total,int lookback,int start_offset,
                          bool draw_pivots,const string &pref_piv,int &prev_piv_count,
                          color pivot_col,int pivot_size)
   {
      bool need = (draw_lines || draw_pivots);
      if(!need){
         ClearZigZagOverlay(pref_lines,prev_line_count);
         ClearPivotMarkers(pref_piv,prev_piv_count);
         return;
      }
      if(handle==INVALID_HANDLE || total<=0){
         ClearZigZagOverlay(pref_lines,prev_line_count);
         ClearPivotMarkers(pref_piv,prev_piv_count);
         return;
      }

      Pivot piv[]; int pc = CollectPivots_ZZ_Handle(handle, high, low, time, total, lookback, piv);
      pc = TrimRecentPivotSegments(piv, MathMax(0, start_offset));

      if(draw_lines){
         int drawn=0;
         for(int i=1;i<pc;i++){
            string nm = pref_lines + IntegerToString(drawn++);
            UpsertTrend(nm, piv[i-1].time, piv[i-1].price, piv[i].time, piv[i].price, line_col, line_width);
         }
         for(int i=drawn;i<prev_line_count;i++) ObjectDelete(ChartID(), pref_lines+IntegerToString(i));
         prev_line_count=drawn;
      }else{
         ClearZigZagOverlay(pref_lines,prev_line_count);
      }

      if(draw_pivots){
         int drawn=0;
         for(int i=0;i<pc;i++){
            string nm = pref_piv + IntegerToString(drawn++);
            UpsertPivotMarker(nm, piv[i].is_high, piv[i].time, piv[i].price, pivot_col, MathMax(1,pivot_size));
         }
         for(int i=drawn;i<prev_piv_count;i++) ObjectDelete(ChartID(), pref_piv+IntegerToString(i));
         prev_piv_count=drawn;
      }else{
         ClearPivotMarkers(pref_piv,prev_piv_count);
      }
   }

   void DrawLegs(const LegSeg &legs[], int leg_count, const VisualConfig &visualCfg)
   {
      if(!visualCfg.show_legs){
         for(int i=0;i<g_ctx.prev_leg_count;i++) ObjectDelete(ChartID(), G_PREF_LEG+IntegerToString(i));
         g_ctx.prev_leg_count=0;
         return;
      }
      int drawn=0;
      for(int i=0;i<leg_count;i++)
      {
         color col = (legs[i].is_up ? visualCfg.leg_up_color : visualCfg.leg_down_color);
         string nm = G_PREF_LEG + IntegerToString(drawn);
         UpsertTrend(nm, legs[i].t1, legs[i].p1, legs[i].t2, legs[i].p2, col, visualCfg.leg_width);
         drawn++;
      }
      for(int i=drawn;i<g_ctx.prev_leg_count;i++) ObjectDelete(ChartID(), G_PREF_LEG+IntegerToString(i));
      g_ctx.prev_leg_count=drawn;
   }

   void ShowSummaryLabel(const string &text)
   {
      const string name="FCZ_SUMMARY";
      long cid=ChartID();
      if(ObjectFind(cid,name)<0) ObjectCreate(cid,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(cid,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(cid,name,OBJPROP_XDISTANCE,6);
      ObjectSetInteger(cid,name,OBJPROP_YDISTANCE,6);
      ObjectSetInteger(cid,name,OBJPROP_FONTSIZE, InpSummaryFontSize);
      ObjectSetString (cid,name,OBJPROP_FONT, "Consolas");
      ObjectSetInteger(cid,name,OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(cid,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(cid,name,OBJPROP_BACK,true);
      ObjectSetString (cid,name,OBJPROP_TEXT,text);
   }

   void ClearSummaryLabel()
   {
      long cid=ChartID();
      bool existed = (ObjectFind(cid,"FCZ_SUMMARY")>=0);
      ObjectDelete(cid,"FCZ_SUMMARY");
      Dbg(StringFormat("[Clear] summary label removed=%s", (existed? "sim" : "não")));
   }

private:
   void ClearZigZagOverlay(const string &pref,int &prev_count)
   {
      for(int i=0;i<prev_count;i++) ObjectDelete(ChartID(), pref+IntegerToString(i));
      Dbg(StringFormat("[Clear] zigzag overlay pref=%s count=%d", pref, prev_count));
      prev_count=0;
   }

   void ClearPivotMarkers(const string &pref,int &prev_count)
   {
      for(int i=0;i<prev_count;i++) ObjectDelete(ChartID(), pref+IntegerToString(i));
      Dbg(StringFormat("[Clear] pivot markers pref=%s count=%d", pref, prev_count));
      prev_count=0;
   }

   void UpsertPivotMarker(const string &name,bool is_high,datetime t,double price,color col,int size)
   {
      long cid=ChartID();
      ENUM_OBJECT type = (is_high? OBJ_ARROW_DOWN : OBJ_ARROW_UP);
      if(ObjectFind(cid,name)<0) ObjectCreate(cid,name,type,0,t,price);
      else ObjectMove(cid,name,0,t,price);
      ObjectSetInteger(cid,name,OBJPROP_COLOR,col);
      ObjectSetInteger(cid,name,OBJPROP_WIDTH,size);
      ObjectSetInteger(cid,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(cid,name,OBJPROP_BACK,false);
   }
};
