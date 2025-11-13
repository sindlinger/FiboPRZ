// Label slot management

extern FiboContext g_ctx;

class LabelManager
{
public:
   void BeginFrame()
   {
      int need = ArraySize(g_ctx.label_slot_identity);
      if(ArraySize(g_ctx.label_slot_used) < need)
         ArrayResize(g_ctx.label_slot_used, need);
      for(int i=0;i<ArraySize(g_ctx.label_slot_used);i++)
         g_ctx.label_slot_used[i]=false;
   }

   int AcquireSlot(const string &identity)
   {
      for(int i=0;i<ArraySize(g_ctx.label_slot_identity);i++)
      {
         if(g_ctx.label_slot_identity[i]==identity)
         {
            if(i>=ArraySize(g_ctx.label_slot_used)){
               int newSize=i+1;
               ArrayResize(g_ctx.label_slot_used,newSize);
            }
            g_ctx.label_slot_used[i]=true;
            return i;
         }
      }
      for(int i=0;i<ArraySize(g_ctx.label_slot_identity);i++)
      {
         if(StringLen(g_ctx.label_slot_identity[i])==0)
         {
            g_ctx.label_slot_identity[i]=identity;
            if(i>=ArraySize(g_ctx.label_slot_used)){
               int newSize=i+1;
               ArrayResize(g_ctx.label_slot_used,newSize);
            }
            g_ctx.label_slot_used[i]=true;
            return i;
         }
      }
      int idx = ArraySize(g_ctx.label_slot_identity);
      ArrayResize(g_ctx.label_slot_identity, idx+1);
      ArrayResize(g_ctx.label_slot_used, idx+1);
      g_ctx.label_slot_identity[idx]=identity;
      g_ctx.label_slot_used[idx]=true;
      return idx;
   }

   void EndFrame()
   {
      long cid = ChartID();
      for(int i=0;i<ArraySize(g_ctx.label_slot_identity);i++)
      {
         bool used = (i<ArraySize(g_ctx.label_slot_used) ? g_ctx.label_slot_used[i] : false);
         if(!used && StringLen(g_ctx.label_slot_identity[i])>0)
         {
            string base = G_PREF_LBL + IntegerToString(i);
            ObjectDelete(cid, base + "_R");
            ObjectDelete(cid, base + "_L");
            g_ctx.label_slot_identity[i]="";
         }
      }
   }

   void ClearAll()
   {
      long cid = ChartID();
      int cleared=0;
      for(int i=0;i<ArraySize(g_ctx.label_slot_identity);i++){
         string base = G_PREF_LBL + IntegerToString(i);
         ObjectDelete(cid, base + "_R");
         ObjectDelete(cid, base + "_L");
         g_ctx.label_slot_identity[i]="";
         if(i<ArraySize(g_ctx.label_slot_used)) g_ctx.label_slot_used[i]=false;
         cleared+=2;
      }
      Dbg(StringFormat("[Clear] price labels slots=%d objects=%d", ArraySize(g_ctx.label_slot_identity), cleared));
   }

   void MaintainPriceLabels(const FibItem &item,int slotIdx,const string &identBase,
                            double price,const string &text,color col,
                            datetime labelLeft,datetime labelRight)
   {
      if(!InpShowLabels){
         string base = G_PREF_LBL + IntegerToString(slotIdx);
         ObjectDelete(ChartID(), base + "_R");
         ObjectDelete(ChartID(), base + "_L");
         return;
      }

      long cid = ChartID();
      bool debugMode = (InpPriceLabelMode==LABEL_MODE_DEBUG);
      string base = G_PREF_LBL + IntegerToString(slotIdx);
      string nmRight = base + "_R";
      string nmLeft  = base + "_L";
      datetime tRight = (labelRight!=0? labelRight : TimeCurrent());
      datetime tLeft  = (labelLeft !=0? labelLeft  : tRight);
      ManageSinglePriceLabel(nmRight, tRight, price, text, col, debugMode, ANCHOR_LEFT, identBase + "_R");
      if(InpLabelsMirrorLeft){
         ManageSinglePriceLabel(nmLeft, tLeft, price, text, col, debugMode, ANCHOR_RIGHT, identBase + "_L");
      }else{
         ObjectDelete(cid, nmLeft);
      }
   }

   static double PriceTolerance(){ return MathMax(_Point*0.1, 1e-8); }
   static long   TimeTolerance(){ long tol=PeriodSeconds(); if(tol<=0) tol=60; return tol; }

private:
   static bool ParseLabelMeta(const string &meta,string &identity,datetime &t,double &p,bool &manualLock)
   {
      identity="";
      t=0;
      p=0.0;
      manualLock=false;
      if(StringLen(meta)==0) return false;
      string parts[];
      int cnt=StringSplit(meta,'|',parts);
      if(cnt<4) return false;
      identity = parts[0];
      long tLong = (long)StringToInteger(parts[1]);
      t = (datetime)tLong;
      p = StringToDouble(parts[2]);
      manualLock = (StringToInteger(parts[3])!=0);
      return true;
   }

   static string BuildLabelMeta(const string &identity,datetime t,double price,bool manualLock)
   {
      string tStr = DoubleToString((double)t,0);
      return identity + "|" + tStr + "|" + DoubleToString(price,10) + "|" + (manualLock? "1":"0");
   }

   void ManageSinglePriceLabel(const string &name, datetime targetTime, double price,
                               const string &text, color col, bool debugMode,
                               ENUM_ANCHOR_POINT anchor, const string identity)
   {
      long cid = ChartID();
      bool exists = (ObjectFind(cid,name)>=0);
      if(!exists){
         ObjectCreate(cid,name,OBJ_TEXT,0,targetTime,price);
         ObjectSetInteger(cid,name,OBJPROP_ANCHOR,anchor);
      }

      string storedId=""; datetime storedTime=0; double storedPrice=0.0; bool manualLock=false;
      string meta=(exists? ObjectGetString(cid,name,OBJPROP_TOOLTIP) : "");
      bool metaValid = ParseLabelMeta(meta, storedId, storedTime, storedPrice, manualLock);
      bool identityMatches = (metaValid && storedId == identity);

      double priceTol = PriceTolerance();
      long timeTol = TimeTolerance();

      if(debugMode && exists && metaValid && !manualLock){
         double currPrice = ObjectGetDouble(cid,name,OBJPROP_PRICE);
         datetime currTime = (datetime)ObjectGetInteger(cid,name,OBJPROP_TIME);
         if(MathAbs(currPrice - storedPrice) > priceTol ||
            MathAbs((long)currTime - (long)storedTime) > timeTol/2)
         {
            manualLock = true;
         }
      }
      if(!debugMode) manualLock=false;

      bool targetChanged = true;
      if(metaValid){
         targetChanged = (MathAbs(price - storedPrice) > priceTol ||
                          MathAbs((long)targetTime - (long)storedTime) > timeTol/2);
      }

      bool mustMove = (!exists || !debugMode || !identityMatches || (!manualLock && targetChanged));
      if(mustMove){
         ObjectMove(cid,name,0,targetTime,price);
         storedTime = targetTime;
         storedPrice = price;
         manualLock = false;
         metaValid = true;
      }else if(!metaValid){
         storedTime = targetTime;
         storedPrice = price;
         manualLock = false;
         metaValid = true;
      }

      ObjectSetString (cid,name,OBJPROP_TEXT,text);
      ObjectSetInteger(cid,name,OBJPROP_COLOR,col);
      ObjectSetInteger(cid,name,OBJPROP_FONTSIZE,8);
      ObjectSetInteger(cid,name,OBJPROP_SELECTABLE,debugMode);
      ObjectSetInteger(cid,name,OBJPROP_BACK,!debugMode);
      ObjectSetInteger(cid,name,OBJPROP_ANCHOR,anchor);

      bool storeManual = (debugMode && manualLock);
      ObjectSetString(cid,name,OBJPROP_TOOLTIP, BuildLabelMeta(identity, storedTime, storedPrice, storeManual));
   }
};
