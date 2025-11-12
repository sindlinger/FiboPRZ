#property copyright "2025"
#property link      ""
#property version   "3.25"
#property strict
#property indicator_chart_window
#property indicator_plots 0

// ========================= Inputs =========================

// -- Enumeradores relacionados aos inputs --
enum ENUM_PRICE_MODE { PRICE_CLUSTER=0, PRICE_RAW=1 };

input group   "ZigZag Primário";
input int      InpZZ_Depth                   = 12;    // ZigZag: Depth
input int      InpZZ_Deviation               = 5;     // ZigZag: Deviation
input int      InpZZ_Backstep                = 3;     // ZigZag: Backstep
input bool     InpShowZigZagPrimary          = false; // overlay: desenhar linhas?
input color    InpZigZagPrimaryColor         = clrDodgerBlue;
input int      InpZigZagPrimaryWidth         = 1;
input bool     InpShowZigZagPrimaryPivots    = false;
input color    InpZigZagPrimaryPivotColor    = clrDodgerBlue;
input int      InpZigZagPrimaryPivotSize     = 1;
input int      InpZigZagPrimaryStartOffset   = 0;     // overlay: ignora X segmentos recentes

input group   "ZigZag Secundário";
input bool     InpShowZigZagSecondary        = false; // desenha 2º ZigZag?
input int      InpZZ2_Depth                  = 34;    // ZigZag2: Depth
input int      InpZZ2_Deviation              = 8;     // ZigZag2: Deviation
input int      InpZZ2_Backstep               = 5;     // ZigZag2: Backstep
input color    InpZigZagSecondaryColor       = clrMediumOrchid;
input int      InpZigZagSecondaryWidth       = 1;
input bool     InpShowZigZagSecondaryPivots  = true;
input color    InpZigZagSecondaryPivotColor  = clrMediumOrchid;
input int      InpZigZagSecondaryPivotSize   = 2;
input int      InpZigZagSecondaryStartOffset = 0;     // overlay: ignora X segmentos recentes

input group   "Pivôs e Pernas";
input int      InpPivotScanLookbackBars  = 500;   // quantas barras recentes escanear
input int      InpPivotStartOffset       = 0;     // ignora X pernas mais recentes (0=mais recente)
input int      InpLegsToUse              = 15;    // quantas pernas usar
input bool     InpShowLegs               = true;  // desenhar pernas (visual)
input color    InpLegUpColor             = clrLime;
input color    InpLegDnColor             = clrOrange;
input int      InpLegWidth               = 1;

input group   "Preço & Tempo";
input bool     InpEnableRetUp            = true;  // preço: retração acima de B (R↑)
input bool     InpEnableRetDown          = true;  // preço: retração abaixo de B (R↓)
input bool     InpEnableExpUp            = true;  // preço: expansão acima de B (X↑)
input bool     InpEnableExpDown          = true;  // preço: expansão abaixo de B (X↓)
input bool     InpTimeBothDirections     = true;  // tempo: adiante e atrás
input bool     InpTimeAllLegs            = false; // tempo: todas as pernas? (false = só base)
input int      InpTimeBaseLeg            = 2;     // tempo: perna base (0 = mais recente)
input int      InpTimeMarkersPerLeg      = 3;     // tempo: quantas razões (máx)
input string   InpFibRatios              = "0.236,0.618,1.0,1.272,1.618,2.0,2.618,3.618,4.236";
input string   InpTimeFibRatios          = "0.618,1.0,1.618,2.618,4.236";

input group   "Janela Diária";
input bool     InpUseDailyWindow         = true;   // limita linhas à janela diária?
input double   InpDailyWindowHeightPctATR = 100.0; // altura = % do ATR(D1)
input double   InpDailyWindowRangeMultiplier = 1.0; // mínimo = múltiplos do range atual (1-5x)
input double   InpDailyWindowWidthDays   = 1.0;    // largura = múltiplos do período D1
input int      InpDailyWindowCenterMAPeriod = 20;  // 0 = meio do candle, >0 = MA(D1) para o centro
input bool     InpShowDailyWindowInfo    = true;   // desenhar dados (centro/hi/lo/ATR) da janela?
input int      InpDailyWindowExtendBars  = 12;     // extensão horizontal extra para rótulos/segmentos

input group   "Clusters";
input int      InpATR_D1_Periods         = 14;     // ATR(1D) período (média de x dias)
input double   InpClusterRangePctATR     = 10.0;   // ESPESSURA do cluster = % do ATR(1D)
input int      InpClusterMinLines        = 14;     // mínimo de linhas para existir cluster (Recomendado)

input group   "Exibição de Preço";
input ENUM_PRICE_MODE InpPriceMode       = PRICE_CLUSTER; // padrão = LINHAS em CLUSTER
input int      InpFibLineWidth           = 1;
input color    InpRetraceLineColor       = clrDeepSkyBlue; // R
input color    InpExpandLineColor        = clrOrangeRed;   // X
input bool     InpShowLabels             = true;           // rótulos (ratio) nas linhas
input bool     InpLabelsMirrorLeft       = true;           // duplicar rótulos no lado esquerdo
input bool     InpLabelShowLeg           = true;           // incluir id da perna no rótulo

input group   "Tempo";
input bool     InpShowTimeFibs           = false;        // liga/desliga marcas de tempo
input bool     InpShowTimeVLines         = true;         // além do ponto, desenhar VLINE
input color    InpTimeDotColor           = clrSilver;
input int      InpTimeDotFontSize        = 8;

input group   "PRZ";
input bool     InpDrawPRZRectangles      = false;     // OFF = padrão (apenas linhas-cluster)
input bool     InpPRZRectUseCustomPctATR = false;     // ON = usar espessura custom abaixo
input double   InpPRZRectThicknessPctATR = 5.0;      // espessura do retângulo (% do ATR 1D) quando custom ON
input color    InpPRZRectColor           = clrAliceBlue;
input int      InpPRZRectBorderWidth     = 1;

input group   "Sombras / Volume";
input bool     InpHighlightShadowClusters   = true;   // destaca clusters com sombras volumosas?
input int      InpShadowVolumeMAPeriod      = 20;     // média móvel de volume (tick) em X períodos
input double   InpShadowVolumeMultiplier    = 1.5;    // volume da barra >= multiplicador * média
input double   InpShadowEqualityTolerance   = 0.05;   // tolerância (0-1) p/ considerar sombras iguais
input color    InpShadowUpperColor          = clrTomato;      // cor quando sombra superior domina
input color    InpShadowLowerColor          = clrDodgerBlue;  // cor quando sombra inferior domina

input group   "Diagnóstico";
input int      InpRightTextMarginBars    = 6;      // margem à direita (texto)
input bool     InpDebugOverlayAllPriceLines = false;
input int      InpDebugLastRetractions   = 0;    // mostra N retrações mais recentes
input int      InpDebugLastExpansions    = 0;    // mostra N expansões mais recentes
input int      InpDebugLastTimeMarks     = 0;    // mostra N marcas de tempo mais recentes
input bool     InpShowSummary            = true;
input bool     InpSummaryShowBreakdown   = true;
input int      InpSummaryFontSize        = 14;
input bool     InpDebugLog               = false;
input int      InpDebugPrintLimit        = 200;

// ========================= Tipos =========================
struct Pivot { double price; datetime time; bool is_high; int index; };
struct LegSeg {
   double p1,p2;
   datetime t1,t2;
   bool is_up;
   int id;
   bool a_is_high;
   bool b_is_high;
   int idx_a;
   int idx_b;
};

struct LineItem { double price; double ratio; bool is_expansion; bool is_up; int leg_id; datetime tB; };
// Tempo carrega o preço do pivô B (priceB) p/ desenhar no MESMO nível:
struct TimeItem { datetime t; double ratio; int leg_id; bool forward; double priceB; };

enum ENUM_FIB_KIND { FIBK_PRICE=0, FIBK_TIME=1 };
struct FibItem {
   ENUM_FIB_KIND kind;
   double   ratio;
   int      leg_id;
   // preço
   double   price; bool is_expansion; bool is_up; datetime tB;
   // tempo
   datetime t; bool forward;
};

enum ENUM_SHADOW_FLAG { SHADOW_NONE=0, SHADOW_UPPER=1, SHADOW_LOWER=2, SHADOW_BOTH=3 };
enum ENUM_DW_FALLBACK_FLAG {
   DW_FALLBACK_NONE    = 0,
   DW_FALLBACK_PRICE   = 1,
   DW_FALLBACK_ATR     = 2
};

// PRZ (opcional)
struct PRZ { double low; double high; int count; double center; };

// ========================= Globais =========================
double          g_fib_ratios[];
double          g_time_ratios[];

string          G_PREF_LINE = "FCZLINE_";
string          G_PREF_LBL  = "FCZLBL_";
string          G_PREF_LEG  = "FCZLEG_";
string          G_PREF_TF   = "FCZTF_";     // pontos de tempo (•)
string          G_PREF_TFVL = "FCZTFVL_";   // vlines de tempo
string          G_PREF_RAW  = "FCZRAW_";
string          G_PREF_PRZ  = "FCZPRZ_";
string          G_PREF_ZZ1  = "FCZZPRI_";
string          G_PREF_ZZ2  = "FCZZSEC_";
string          G_PREF_SHADOW = "FCZSHADOW_";
string          G_PREF_ZZ1_PIV = "FCZZPIV1_";
string          G_PREF_ZZ2_PIV = "FCZZPIV2_";
string          G_PREF_WARN_DW = "FCZWARN_DW";
string          G_PREF_DW_INFO = "FCZDWINFO";
string          G_PREF_DBG_RET = "FCZDBG_RET_";
string          G_PREF_DBG_RET_LBL = "FCZDBG_RETLBL_";
string          G_PREF_DBG_EXP = "FCZDBG_EXP_";
string          G_PREF_DBG_EXP_LBL = "FCZDBG_EXPLBL_";
string          G_PREF_DBG_TIME = "FCZDBG_TIME_DOT_";
string          G_PREF_DBG_TIME_VL = "FCZDBG_TIME_VL_";

int             g_prev_line_count = 0;
int             g_prev_leg_count  = 0;
int             g_prev_tf_count   = 0;
int             g_prev_tfvl_count = 0;
int             g_prev_raw_count  = 0;
int             g_prev_prz_count  = 0;
int             g_prev_zz1_count  = 0;
int             g_prev_zz2_count  = 0;
int             g_prev_shadow_count = 0;
int             g_prev_zz1_piv_count = 0;
int             g_prev_zz2_piv_count = 0;
int             g_prev_dbg_ret_count = 0;
int             g_prev_dbg_exp_count = 0;
int             g_prev_dbg_time_dot_count = 0;
int             g_prev_dbg_time_vl_count = 0;

int             g_dbg_prints = 0;

bool            g_dw_active = false;
datetime        g_dw_time_left = 0;
datetime        g_dw_time_right = 0;

// bases e views
LineItem        g_price_all[];   int g_price_total = 0;
TimeItem        g_time_all[];    int g_time_total  = 0;

FibItem         g_all[];         int g_all_total   = 0;
int             g_view_price[];
int             g_view_time[];

// PRZs
PRZ             g_prz[];
int             g_prz_count = 0;
int             g_prz_shadow_flag[];

// contadores
int             g_R_all=0, g_X_all=0;
int             g_visible_cluster_lines = 0;
int             g_pivot_total=0, g_pivot_tops=0, g_pivot_bottoms=0;
int             g_leg_total=0;

// ZigZag handles
int             g_zz_handle  = INVALID_HANDLE;
int             g_zz2_handle = INVALID_HANDLE;

// ========================= Utils =========================
void Dbg(const string &s){ if(!InpDebugLog) return; if(g_dbg_prints>=InpDebugPrintLimit) return; Print(s); g_dbg_prints++; }
void LogAlways(const string &s){ Print(s); }
string Trim(const string &v){ string r=v; StringTrimLeft(r); StringTrimRight(r); return r; }

bool ParseRatiosTo(const string &text, double &arr[])
{
   ArrayResize(arr,0);
   string tok[]; int c=StringSplit(text,',',tok);
   if(c<=0) return false;
   for(int i=0;i<c;i++){ string t=Trim(tok[i]); if(StringLen(t)==0) continue;
      double r=StringToDouble(t); if(r<=0.0) continue;
      int n=ArraySize(arr)+1; ArrayResize(arr,n); arr[n-1]=r; }
   return ArraySize(arr)>0;
}

bool IsSeries(const datetime &time[],int total){ return (total>1 && time[0]>time[1]); }

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
   if(t1>t2){ datetime tmp=t1; t1=t2; t2=tmp; }
   long cid=ChartID();
   if(ObjectFind(cid,name)<0) ObjectCreate(cid,name,OBJ_TREND,0,t1,price,t2,price);
   else{
      ObjectMove(cid,name,0,t1,price);
      ObjectMove(cid,name,1,t2,price);
   }
   ObjectSetInteger(cid,name,OBJPROP_COLOR,col);
   ObjectSetInteger(cid,name,OBJPROP_WIDTH,w);
   ObjectSetInteger(cid,name,OBJPROP_STYLE,style);
   ObjectSetInteger(cid,name,OBJPROP_RAY,false);
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
void UpsertPRZRect(const string &name, datetime t_left, datetime t_right, double low, double high, color col, int border_w)
{
   long cid=ChartID();
   if(ObjectFind(cid,name)<0) ObjectCreate(cid,name,OBJ_RECTANGLE,0,t_left,low,t_right,high);
   else{ ObjectMove(cid,name,0,t_left,low); ObjectMove(cid,name,1,t_right,high); }
   ObjectSetInteger(cid,name,OBJPROP_BACK,true);
   ObjectSetInteger(cid,name,OBJPROP_COLOR,col);
   ObjectSetInteger(cid,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(cid,name,OBJPROP_WIDTH,border_w);
   ObjectSetInteger(cid,name,OBJPROP_FILL,true);
}
void ClearByPrefix(const string &pref)
{
   long cid=ChartID();
   int total=ObjectsTotal(cid,0,-1);
   for(int i=total-1;i>=0;--i){
      string nm=ObjectName(cid,i,0);
      if(StringFind(nm,pref)==0) ObjectDelete(cid,nm);
   }
}
void ClearPRZObjects()
{
   for(int i=0;i<g_prev_prz_count;i++){
      ObjectDelete(ChartID(), G_PREF_PRZ + IntegerToString(i));
      ObjectDelete(ChartID(), G_PREF_PRZ + "LBL_" + IntegerToString(i));
   }
   g_prev_prz_count=0;
}
int LowerBound(const double &A[], int N, double x){
   int lo=0, hi=N;
   while(lo<hi){
      int mid=(lo+hi)>>1;
      if(A[mid] < x) lo=mid+1; else hi=mid;
   }
   return lo;
}
int UpperBound(const double &A[], int N, double x){
   int lo=0, hi=N;
   while(lo<hi){
      int mid=(lo+hi)>>1;
      if(A[mid] <= x) lo=mid+1; else hi=mid;
   }
   return lo;
}
bool RangeIntersects(double a1,double a2,double b1,double b2)
{
   double loA=MathMin(a1,a2), hiA=MathMax(a1,a2);
   double loB=MathMin(b1,b2), hiB=MathMax(b1,b2);
   return !(hiA < loB || hiB < loA);
}
bool CalcIntradayDayRange(const datetime &time[], const double &high[], const double &low[],
                          int total, datetime dayStart, datetime dayEnd,
                          double &outHigh, double &outLow)
{
   if(total<=0 || dayStart<=0 || dayEnd<=dayStart) return false;
   bool series = IsSeries(time,total);
   double hi = -1e100, lo = 1e100;
   bool got=false;
   if(series){
      for(int i=0;i<total;i++){
         datetime t=time[i];
         if(t < dayStart) break;
         if(t>dayEnd) continue;
         if(!MathIsValidNumber(high[i]) || !MathIsValidNumber(low[i])) continue;
         if(!got){ hi=high[i]; lo=low[i]; got=true; }
         else{
            if(high[i]>hi) hi=high[i];
            if(low[i]<lo) lo=low[i];
         }
      }
   }else{
      for(int i=0;i<total;i++){
         datetime t=time[i];
         if(t < dayStart || t>dayEnd) continue;
         if(!MathIsValidNumber(high[i]) || !MathIsValidNumber(low[i])) continue;
         if(!got){ hi=high[i]; lo=low[i]; got=true; }
         else{
            if(high[i]>hi) hi=high[i];
            if(low[i]<lo) lo=low[i];
         }
      }
   }
   if(!got || hi<=lo) return false;
   outHigh=hi;
   outLow =lo;
   return true;
}

bool GetDailyWindowBounds(const datetime &time[], const double &high[], const double &low[],
                          int total, double &out_low,double &out_high,
                          double &out_mid,double &out_atr,int &fallback_flags,
                          datetime &out_t_start, datetime &out_t_end,
                          bool &out_center_from_ma)
{
   fallback_flags = DW_FALLBACK_NONE;
   out_center_from_ma = false;

   int daySeconds = PeriodSeconds(PERIOD_D1);
   if(daySeconds<=0) daySeconds=86400;
   datetime dayStart = iTime(_Symbol, PERIOD_D1, 0);
   if(dayStart<=0){
      if(total>0){
         bool series = IsSeries(time,total);
         datetime latest = time[series?0:total-1];
         long baseDay = ((long)latest / daySeconds) * (long)daySeconds;
         dayStart = (datetime)baseDay;
      }else{
         long now = (long)TimeCurrent();
         long baseDay = (now / daySeconds) * (long)daySeconds;
         dayStart = (datetime)baseDay;
      }
   }
   datetime dayEnd = (datetime)((long)dayStart + daySeconds);

   double dayHigh=0.0, dayLow=0.0;
   bool haveIntraday = CalcIntradayDayRange(time, high, low, total, dayStart, dayEnd, dayHigh, dayLow);
   if(!haveIntraday || dayHigh<=dayLow){
      dayHigh = iHigh(_Symbol, PERIOD_D1, 0);
      dayLow  = iLow (_Symbol, PERIOD_D1, 0);
      bool haveDaily = (MathIsValidNumber(dayHigh) && MathIsValidNumber(dayLow) && dayHigh>dayLow);
      if(!haveDaily) return false;
      fallback_flags |= DW_FALLBACK_PRICE;
   }

   double baseRange = dayHigh - dayLow;
   double atrD1 = 0.0;
   if(!GetATR_D1(InpATR_D1_Periods, atrD1) || atrD1<=0.0){
      atrD1 = baseRange;
      fallback_flags |= DW_FALLBACK_ATR;
   }

   double center = (dayHigh + dayLow) * 0.5;
   int centerPeriod = MathMax(0, InpDailyWindowCenterMAPeriod);
   if(centerPeriod>0){
      int maHandle = iMA(_Symbol, PERIOD_D1, centerPeriod, 0, MODE_SMA, PRICE_TYPICAL);
      if(maHandle!=INVALID_HANDLE){
         double buf[];
         int copied = CopyBuffer(maHandle,0,0,1,buf);
         IndicatorRelease(maHandle);
         if(copied>0 && MathIsValidNumber(buf[0])){
            center = buf[0];
            out_center_from_ma = true;
         }
      }
   }

   double pct = MathMax(0.01, InpDailyWindowHeightPctATR);
   double spanAtr = atrD1 * (pct/100.0);
   double mult = MathMin(5.0, MathMax(1.0, InpDailyWindowRangeMultiplier));
   double spanRange = baseRange * mult;
   double span = MathMax(spanAtr, spanRange);
   if(span<=0.0){
      span = baseRange;
      fallback_flags |= DW_FALLBACK_PRICE;
   }
   double half = span * 0.5;

   out_low  = center - half;
   out_high = center + half;
   out_mid  = center;
   out_atr  = atrD1;

   datetime dStart = dayStart;
   datetime dEnd   = dayEnd;
   double widthDays = MathMax(0.1, InpDailyWindowWidthDays);
   long widthSeconds = (long)MathRound(widthDays * (double)daySeconds);
   if(widthSeconds<=0) widthSeconds = daySeconds;
   long halfWidth = widthSeconds/2;
   datetime midTime = (datetime)((long)dStart + (long)(MathMax(1, daySeconds)/2));
   datetime baseStart = (datetime)((long)midTime - halfWidth);
   datetime baseEnd   = (datetime)((long)midTime + halfWidth);
   int extendBars = MathMax(0, InpDailyWindowExtendBars);
   int ps = PeriodSeconds(); if(ps<=0) ps=60;
   long ext = (long)ps * extendBars;
   out_t_start = (datetime)((long)baseStart - ext);
   out_t_end   = (datetime)((long)baseEnd   + ext);

   return (out_low < out_high);
}

void ShowDailyWindowFallbackNotice(int flags)
{
   const string name = G_PREF_WARN_DW;
   if(flags==DW_FALLBACK_NONE){
      ObjectDelete(ChartID(), name);
      return;
   }
   string parts="";
   if((flags & DW_FALLBACK_PRICE)!=0) parts = "Hi/Lo intraday";
   if((flags & DW_FALLBACK_ATR)!=0){
      if(parts!="") parts += " + ";
      parts += "ATR substituído";
   }
   if(parts=="") parts="fallback ativo";
   if(ObjectFind(ChartID(), name)<0) ObjectCreate(ChartID(), name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(ChartID(), name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(ChartID(), name, OBJPROP_XDISTANCE, 6);
   ObjectSetInteger(ChartID(), name, OBJPROP_YDISTANCE, 6 + InpSummaryFontSize*3);
   ObjectSetInteger(ChartID(), name, OBJPROP_FONTSIZE, MathMax(8, InpSummaryFontSize-2));
   ObjectSetInteger(ChartID(), name, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(ChartID(), name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(ChartID(), name, OBJPROP_BACK, true);
   ObjectSetString(ChartID(), name, OBJPROP_FONT, "Consolas");
   ObjectSetString(ChartID(), name, OBJPROP_TEXT, "Aviso: janela diária fallback ("+parts+")");
}
void ShowDailyWindowInfo(bool enabled,bool hasData,double low,double high,double mid,double atr,int flags,double span,bool centerFromMA)
{
   const string name = G_PREF_DW_INFO;
   if(!enabled){
      ObjectDelete(ChartID(), name);
      return;
   }
   if(!hasData){
      string text = "Janela D1: dados indisponíveis (?)";
      if(ObjectFind(ChartID(), name)<0) ObjectCreate(ChartID(), name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(ChartID(), name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(ChartID(), name, OBJPROP_XDISTANCE, 6);
      ObjectSetInteger(ChartID(), name, OBJPROP_YDISTANCE, 6 + InpSummaryFontSize*5);
      ObjectSetInteger(ChartID(), name, OBJPROP_FONTSIZE, MathMax(8, InpSummaryFontSize-2));
      ObjectSetInteger(ChartID(), name, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(ChartID(), name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(ChartID(), name, OBJPROP_BACK, true);
      ObjectSetString(ChartID(), name, OBJPROP_FONT, "Consolas");
      ObjectSetString(ChartID(), name, OBJPROP_TEXT, text);
      return;
   }
   string fonte = "ATR% + Range";
   if((flags & DW_FALLBACK_ATR)!=0) fonte = "RangeOnly";
   if((flags & DW_FALLBACK_PRICE)!=0) fonte += "+Fallback";
   double altura = MathMax(0.0, high-low);
   double percReal = (atr>0.0 ? (altura/atr)*100.0 : 0.0);
   double percCfg  = MathMax(0.0, InpDailyWindowHeightPctATR);
   string realText = (atr>0.0 ? StringFormat("%.1f%% ATR", percReal) : "n/d");
   string cfgText  = StringFormat("AlturaCfg=%.1f%% ATR", percCfg);
   string rangeText = StringFormat(">=%.1fx Range", MathMax(1.0, MathMin(5.0, InpDailyWindowRangeMultiplier)));
   string centerText = (centerFromMA && InpDailyWindowCenterMAPeriod>0?
                        StringFormat("Centro=MA(%d)", InpDailyWindowCenterMAPeriod) :
                        "Centro=mid D1");
   string widthText = StringFormat("Largura=%.2f D1", MathMax(0.1, InpDailyWindowWidthDays));
   string text = StringFormat(
      "Janela D1  Low:%.5f  High:%.5f  Centro:%.5f  Altura:%.5f  Real:%s  %s  %s  %s  Span:%.5f  ATR usado:%.5f (p=%d)  Fonte:%s",
      low, high, mid, altura, realText, cfgText, rangeText, widthText, span, atr, InpATR_D1_Periods, fonte);

   if(InpDebugLog)
      Dbg(StringFormat("[DW] low=%.5f high=%.5f mid=%.5f alt=%.5f span=%.5f real=%.1f cfg=%.1f rangeMult=%.1f widthDays=%.2f atr=%.5f centroMA=%s fonte=%s",
                       low, high, mid, altura, span, percReal, percCfg,
                       MathMax(1.0, MathMin(5.0, InpDailyWindowRangeMultiplier)),
                       MathMax(0.1, InpDailyWindowWidthDays), atr,
                       (centerFromMA? "SIM" : "NAO"), fonte));
   if(ObjectFind(ChartID(), name)<0) ObjectCreate(ChartID(), name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(ChartID(), name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(ChartID(), name, OBJPROP_XDISTANCE, 6);
   ObjectSetInteger(ChartID(), name, OBJPROP_YDISTANCE, 6 + InpSummaryFontSize*5);
   ObjectSetInteger(ChartID(), name, OBJPROP_FONTSIZE, MathMax(8, InpSummaryFontSize-2));
   ObjectSetInteger(ChartID(), name, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(ChartID(), name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(ChartID(), name, OBJPROP_BACK, true);
   ObjectSetString(ChartID(), name, OBJPROP_FONT, "Consolas");
   ObjectSetString(ChartID(), name, OBJPROP_TEXT, text);
}
void ApplyDailyWindowFilter(const FibItem &all[], int &idx_price[], double wlow,double whigh)
{
   if(wlow>=whigh) return;
   int out=0;
   for(int i=0;i<ArraySize(idx_price);i++){
      int idx = idx_price[i];
      if(idx<0 || idx>=ArraySize(all)) continue;
      double price = all[idx].price;
      if(price >= wlow && price <= whigh){
         idx_price[out++] = idx;
      }
   }
   ArrayResize(idx_price,out);
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
void ClearSummaryLabel(){ ObjectDelete(ChartID(),"FCZ_SUMMARY"); }

// ========================= ATR(1D) =========================
bool GetATR_D1(int atr_periods, double &atr_out)
{
   atr_out=0.0;
   if(atr_periods<=0) return false;
   int h=iATR(_Symbol, PERIOD_D1, atr_periods);
   if(h==INVALID_HANDLE) return false;
   double buf[];
   int copied=CopyBuffer(h,0,0,1,buf);
   IndicatorRelease(h);
   if(copied<=0) return false;
   atr_out=buf[0];
   return (atr_out>0.0);
}

// ========================= Janela visível =========================
bool GetVisibleWindow(const datetime &time[], int total,
                      datetime &t_left, datetime &t_right,
                      double &p_min, double &p_max)
{
   long first=0, bars=0;
   if(!ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR, 0, first)) return false;
   if(!ChartGetInteger(0, CHART_VISIBLE_BARS,     0, bars )) return false;

   int idx_left  = (int)first;
   int idx_right = (int)MathMax(0, (int)first - (int)bars + 1);

   if(total<=0) return false;
   idx_left  = (int)MathMin(MathMax(idx_left,  0), total-1);
   idx_right = (int)MathMin(MathMax(idx_right, 0), total-1);

   t_left  = time[idx_left];
   t_right = time[idx_right];
   if(t_left>t_right){ datetime tmp=t_left; t_left=t_right; t_right=tmp; }

   int ps=PeriodSeconds(); if(ps<=0) ps=60;
   t_right = (datetime)((long)t_right + ps*InpRightTextMarginBars);

   double vmin=0, vmax=0;
   if(!ChartGetDouble(0, CHART_PRICE_MIN, 0, vmin)) return false;
   if(!ChartGetDouble(0, CHART_PRICE_MAX, 0, vmax)) return false;
   if(vmin>vmax){ double tmp=vmin; vmin=vmax; vmax=tmp; }

   p_min = vmin; p_max = vmax;
   return true;
}

// ========================= Pivôs (apenas ZigZag) =========================
int CollectPivots_ZZ_Handle(int handle,
                            const double &high[],const double &low[],const datetime &time[],
                            int total,int lookback,
                            Pivot &pivots[])
{
   ArrayResize(pivots,0);
   if(total<=0 || handle==INVALID_HANDLE) return 0;

   int use = MathMin(lookback, total);
   bool series = IsSeries(time, total);
   int from = series? 0 : total - use;
   int to   = series? use-1 : total-1;
   if(from<0) from=0; if(to<0) return 0;

   static double top_buf[], bot_buf[];
   int cTop = CopyBuffer(handle, 0, 0, total, top_buf);
   int cBot = CopyBuffer(handle, 1, 0, total, bot_buf);
   if(cTop<=0 && cBot<=0) return 0;

   for(int i=from; i<=to; ++i)
   {
      bool isHigh = (i<cTop && top_buf[i]!=0.0);
      bool isLow  = (i<cBot && bot_buf[i]!=0.0);
      if(!isHigh && !isLow) continue;
      if(isHigh){
         double price = top_buf[i];
         if(price!=0.0){
            int n=ArraySize(pivots)+1; ArrayResize(pivots,n);
            pivots[n-1].price   = price;
            pivots[n-1].time    = time[i];
            pivots[n-1].is_high = true;
            pivots[n-1].index   = i;
         }
      }
      if(isLow){
         double price = bot_buf[i];
         if(price!=0.0){
            int n=ArraySize(pivots)+1; ArrayResize(pivots,n);
            pivots[n-1].price   = price;
            pivots[n-1].time    = time[i];
            pivots[n-1].is_high = false;
            pivots[n-1].index   = i;
         }
      }
   }

   // ordenar por tempo crescente + deduplicar por tempo
   int N=ArraySize(pivots);
   for(int a=0;a<N-1;a++){
      int best=a;
      for(int b=a+1;b<N;b++) if(pivots[b].time < pivots[best].time) best=b;
      if(best!=a){ Pivot t=pivots[a]; pivots[a]=pivots[best]; pivots[best]=t; }
   }
   int w=0;
   for(int i=0;i<N;i++){
      if(i==0 || pivots[i].time!=pivots[w-1].time){
         if(w!=i) pivots[w]=pivots[i];
         w++;
      }
   }
   ArrayResize(pivots,w);
   return w;
}
int CollectPivots_ZZ(const double &high[],const double &low[],const datetime &time[],
                     int total,int lookback,
                     Pivot &pivots[])
{
   return CollectPivots_ZZ_Handle(g_zz_handle, high, low, time, total, lookback, pivots);
}

void BuildLegsFromPivots(const Pivot &piv[],int piv_count,int legs_to_use, LegSeg &legs[],int &leg_count)
{
   ArrayResize(legs,0); leg_count=0;
   if(piv_count<2 || legs_to_use<=0) return;

   int skip = MathMax(0, InpPivotStartOffset);
   int start = piv_count-2 - skip;
   if(start > piv_count-2) start = piv_count-2;
   int built=0;
   for(int i=start; i>=0 && built<legs_to_use; --i)
   {
      Pivot pA = piv[i];
      Pivot pB = piv[i+1];

      // precisa ser Topo->Fundo ou vice-versa para haver perna
      if(pA.is_high == pB.is_high){
         Dbg(StringFormat("Leg descartada (mesmo tipo de pivô) idxA=%d idxB=%d", pA.index, pB.index));
         continue;
      }
      // pB deve ser o pivô mais recente
      if(pB.time <= pA.time){
         Dbg(StringFormat("Leg descartada (ordem temporal inválida) tA=%s tB=%s",
                          TimeToString(pA.time), TimeToString(pB.time)));
         continue;
      }

      LegSeg Lg;
      Lg.t1 = pA.time;   Lg.p1 = pA.price;
      Lg.t2 = pB.time;   Lg.p2 = pB.price;
      Lg.a_is_high = pA.is_high;
      Lg.b_is_high = pB.is_high;
      Lg.idx_a = pA.index;
      Lg.idx_b = pB.index;

      Lg.is_up = (Lg.p2>Lg.p1);
      Lg.id    = built;

      int n=ArraySize(legs)+1; ArrayResize(legs,n); legs[n-1]=Lg; built++;
   }
   leg_count=ArraySize(legs);
}

void DrawLegs(const LegSeg &legs[], int leg_count)
{
   if(!InpShowLegs){
      for(int i=0;i<g_prev_leg_count;i++) ObjectDelete(ChartID(), G_PREF_LEG+IntegerToString(i));
      g_prev_leg_count=0;
      return;
   }
   int drawn=0;
   for(int i=0;i<leg_count;i++)
   {
      color col = (legs[i].is_up ? InpLegUpColor : InpLegDnColor);
      string nm = G_PREF_LEG + IntegerToString(drawn);
      UpsertTrend(nm, legs[i].t1, legs[i].p1, legs[i].t2, legs[i].p2, col, InpLegWidth);
      drawn++;
   }
   for(int i=drawn;i<g_prev_leg_count;i++) ObjectDelete(ChartID(), G_PREF_LEG+IntegerToString(i));
   g_prev_leg_count=drawn;
}

void ClearZigZagOverlay(const string &pref,int &prev_count)
{
   for(int i=0;i<prev_count;i++) ObjectDelete(ChartID(), pref+IntegerToString(i));
   prev_count=0;
}
void ClearPivotMarkers(const string &pref,int &prev_count)
{
   for(int i=0;i<prev_count;i++) ObjectDelete(ChartID(), pref+IntegerToString(i));
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
   int usable_pc = pc;
   int skip = MathMax(0, start_offset);
   if(skip>0){
      usable_pc = MathMax(0, pc - skip);
   }

   if(draw_lines){
      int drawn=0;
      for(int i=1;i<usable_pc;i++){
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
      for(int i=0;i<usable_pc;i++){
         string nm = pref_piv + IntegerToString(drawn++);
         UpsertPivotMarker(nm, piv[i].is_high, piv[i].time, piv[i].price, pivot_col, MathMax(1,pivot_size));
      }
      for(int i=drawn;i<prev_piv_count;i++) ObjectDelete(ChartID(), pref_piv+IntegerToString(i));
      prev_piv_count=drawn;
   }else{
      ClearPivotMarkers(pref_piv,prev_piv_count);
   }
}

void ClearShadowClusterRects()
{
   for(int i=0;i<g_prev_shadow_count;i++) ObjectDelete(ChartID(), G_PREF_SHADOW+IntegerToString(i));
   g_prev_shadow_count=0;
}

void EvaluateShadowClusters(const datetime &time[],
                            const double &open[],const double &high[],
                            const double &low[],const double &close[],
                            const long &tick_volume[],
                            int total)
{
   ArrayResize(g_prz_shadow_flag, g_prz_count);
   for(int i=0;i<g_prz_count;i++) g_prz_shadow_flag[i]=SHADOW_NONE;
   if(!InpHighlightShadowClusters || g_prz_count<=0 || total<=0) return;

   int period=MathMax(1, InpShadowVolumeMAPeriod);
   double avgVol[]; ArrayResize(avgVol,total);
   double window[]; ArrayResize(window,period);
   int wpos=0, filled=0;
   double sum=0.0;
   bool series=IsSeries(time,total);
   int start = series? total-1 : 0;
   int end   = series? 0 : total-1;
   int step  = series? -1 : 1;

   for(int idx=start; series? idx>=end : idx<=end; idx+=step)
   {
      double v = (double)tick_volume[idx];
      if(filled<period){
         window[wpos]=v;
         sum+=v;
         filled++;
      }else{
         sum -= window[wpos];
         window[wpos]=v;
         sum += v;
      }
      wpos++; if(wpos>=period) wpos=0;
      int div = (filled<period? filled : period);
      double avg = (div>0? sum/div : v);
      avgVol[idx]=avg;
   }

   int iterStart = series? 0 : total-1;
   int iterEnd   = series? total-1 : 0;
   int iterStep  = series? 1 : -1;
   double tol = MathMax(0.0, InpShadowEqualityTolerance);
   int remaining = g_prz_count;
   for(int idx=iterStart; series? idx<=iterEnd : idx>=iterEnd; idx+=iterStep)
   {
      double avg = avgVol[idx];
      if(avg<=0) continue;
      double vol = (double)tick_volume[idx];
      if(vol < InpShadowVolumeMultiplier * avg) continue;

      double o=open[idx], c=close[idx], h=high[idx], l=low[idx];
      double body = MathAbs(c-o);
      double half_body = 0.5 * body;
      double body_high = MathMax(o,c);
      double body_low  = MathMin(o,c);
      double upper = h - body_high;
      double lower = body_low - l;
      bool upperLenOk = (upper > half_body);
      bool lowerLenOk = (lower > half_body);
      if(!upperLenOk && !lowerLenOk) continue;

      for(int j=0;j<g_prz_count;j++)
      {
         if(g_prz_shadow_flag[j]!=SHADOW_NONE) continue;
         double cl = g_prz[j].low;
         double ch = g_prz[j].high;
         bool upperHits = upperLenOk && RangeIntersects(body_high, h, cl, ch);
         bool lowerHits = lowerLenOk && RangeIntersects(l, body_low, cl, ch);
         if(!upperHits && !lowerHits) continue;

         int flag = SHADOW_NONE;
         if(upperHits && lowerHits){
            double sumW = upper + lower;
            bool equal = (sumW>0 && MathAbs(upper-lower) <= tol * sumW);
            if(equal) flag = SHADOW_BOTH;
            else      flag = (upper > lower ? SHADOW_UPPER : SHADOW_LOWER);
         }else if(upperHits) flag = SHADOW_UPPER;
         else if(lowerHits)  flag = SHADOW_LOWER;

         if(flag!=SHADOW_NONE){
            g_prz_shadow_flag[j]=flag;
            remaining--;
            if(remaining<=0) return;
         }
      }
   }
}

void DrawShadowClusterRects(const datetime &time[], int total)
{
   if(!InpHighlightShadowClusters || g_prz_count<=0){
      ClearShadowClusterRects();
      return;
   }

   datetime tL=0,tR=0; double pmin=0,pmax=0;
   if(!GetVisibleWindow(time,total,tL,tR,pmin,pmax)){
      bool series=IsSeries(time,total);
      int ps=PeriodSeconds(); if(ps<=0) ps=60;
      tL = time[series? total-1 : 0];
      tR = (datetime)((long)time[series? 0 : total-1] + ps*InpRightTextMarginBars);
   }

   int drawn=0;
   for(int i=0;i<g_prz_count;i++){
      int flag = (i<ArraySize(g_prz_shadow_flag)? g_prz_shadow_flag[i] : SHADOW_NONE);
      if(flag==SHADOW_NONE) continue;
      double low = g_prz[i].low;
      double high = g_prz[i].high;
      if(flag==SHADOW_BOTH){
         double mid = (low+high)*0.5;
         string nmLow = G_PREF_SHADOW + IntegerToString(drawn++);
         UpsertPRZRect(nmLow, tL, tR, low, mid, InpShadowLowerColor, InpPRZRectBorderWidth);
         ObjectSetInteger(ChartID(), nmLow, OBJPROP_BACK, false);
         string nmHigh = G_PREF_SHADOW + IntegerToString(drawn++);
         UpsertPRZRect(nmHigh, tL, tR, mid, high, InpShadowUpperColor, InpPRZRectBorderWidth);
         ObjectSetInteger(ChartID(), nmHigh, OBJPROP_BACK, false);
      }else{
         color col = (flag==SHADOW_UPPER? InpShadowUpperColor : InpShadowLowerColor);
         string nm = G_PREF_SHADOW + IntegerToString(drawn++);
         UpsertPRZRect(nm, tL, tR, low, high, col, InpPRZRectBorderWidth);
         ObjectSetInteger(ChartID(), nm, OBJPROP_BACK, false);
      }
   }
   for(int i=drawn;i<g_prev_shadow_count;i++) ObjectDelete(ChartID(), G_PREF_SHADOW+IntegerToString(i));
   g_prev_shadow_count = drawn;
}

// ========================= Linhas de PREÇO (geração) =================
string RatioTag(double ratio){ double pct=ratio*100.0; bool is_exp=(pct>100.0); return StringFormat("%s%.1f",(is_exp? "X":"R"),pct); }
string BuildLineLabelText(const FibItem &item)
{
   string text = RatioTag(item.ratio);
   text += (item.is_up? "+" : "-");
   if(InpLabelShowLeg) text += StringFormat(" L%d", item.leg_id);
   return text;
}
void MaintainPriceLabels(int idx,double price,const string &text,color col,datetime labelLeft,datetime labelRight)
{
   string base = G_PREF_LBL + IntegerToString(idx);
   string nmRight = base + "_R";
   string nmLeft  = base + "_L";
   datetime tRight = (labelRight!=0? labelRight : TimeCurrent());
   if(InpShowLabels){
      UpsertText(nmRight, tRight, price, text, col, 8, ANCHOR_LEFT);
      if(InpLabelsMirrorLeft){
         datetime tLeft = (labelLeft!=0? labelLeft : tRight);
         UpsertText(nmLeft, tLeft, price, text, col, 8, ANCHOR_RIGHT);
      }else{
         ObjectDelete(ChartID(), nmLeft);
      }
   }else{
      ObjectDelete(ChartID(), nmRight);
      ObjectDelete(ChartID(), nmLeft);
   }
}

void BuildAllPriceLines(const LegSeg &legs[],int leg_count,
                        LineItem &out[],int &out_count)
{
   ArrayResize(out,0); out_count=0;
   if(leg_count<=0 || ArraySize(g_fib_ratios)==0) return;

   for(int i=0;i<leg_count;i++)
   {
      if(legs[i].t2 <= legs[i].t1){
         Dbg(StringFormat("Perna %d ignorada em preço (ponto B não é mais recente).", legs[i].id));
         continue;
      }
      double B = legs[i].p2;
      double d = MathAbs(legs[i].p2 - legs[i].p1);
      if(d < _Point) continue;

      bool selRUp   = InpEnableRetUp;
      bool selRDown = InpEnableRetDown;
      bool selXUp   = InpEnableExpUp;
      bool selXDown = InpEnableExpDown;

      for(int r=0;r<ArraySize(g_fib_ratios);r++)
      {
         double ratio = g_fib_ratios[r];
         bool is_exp  = (ratio>1.0);

         double up_price = B + ratio*d; // ↑
         double dn_price = B - ratio*d; // ↓

         if(!is_exp){ // RETRAÇÕES
            if(selRUp){
               int n=ArraySize(out)+1; ArrayResize(out,n);
               out[n-1].price=up_price; out[n-1].ratio=ratio; out[n-1].is_expansion=false; out[n-1].is_up=true;  out[n-1].leg_id=legs[i].id; out[n-1].tB=legs[i].t2;
            }
            if(selRDown){
               int n=ArraySize(out)+1; ArrayResize(out,n);
               out[n-1].price=dn_price; out[n-1].ratio=ratio; out[n-1].is_expansion=false; out[n-1].is_up=false; out[n-1].leg_id=legs[i].id; out[n-1].tB=legs[i].t2;
            }
         }else{       // EXPANSÕES
            if(selXUp){
               int n=ArraySize(out)+1; ArrayResize(out,n);
               out[n-1].price=up_price; out[n-1].ratio=ratio; out[n-1].is_expansion=true;  out[n-1].is_up=true;  out[n-1].leg_id=legs[i].id; out[n-1].tB=legs[i].t2;
            }
            if(selXDown){
               int n=ArraySize(out)+1; ArrayResize(out,n);
               out[n-1].price=dn_price; out[n-1].ratio=ratio; out[n-1].is_expansion=true;  out[n-1].is_up=false; out[n-1].leg_id=legs[i].id; out[n-1].tB=legs[i].t2;
            }
         }
      }
   }
   out_count=ArraySize(out);
}

// ========================= Fibonacci de TEMPO ========================
void BuildTimeMarks(const LegSeg &legs[], int leg_count, TimeItem &marks[], int &marks_count)
{
   ArrayResize(marks,0); marks_count=0;
   if(ArraySize(g_time_ratios)==0 || InpTimeMarkersPerLeg<=0 || leg_count<=0) return;

   int ps = PeriodSeconds(); if(ps<=0) ps=60;

   int fromLeg=0, toLeg=-1;
   if(InpTimeAllLegs){ fromLeg=0; toLeg=leg_count-1; }
   else{
      int base=InpTimeBaseLeg; if(base<0) base=0; if(base>=leg_count) base=0;
      fromLeg=base; toLeg=base;
   }

   int count = MathMin(InpTimeMarkersPerLeg, ArraySize(g_time_ratios));

   for(int L=fromLeg; L<=toLeg; L++)
   {
      long dt = (long)legs[L].t2 - (long)legs[L].t1;
      if(dt<=0){
         Dbg(StringFormat("Perna %d ignorada em tempo (ponto B não é mais recente).", legs[L].id));
         continue;
      }

      for(int i=0;i<count;i++)
      {
         double rr = g_time_ratios[i];
         long off = (long)(rr * (double)dt);
         long snap = off - (off % ps); // alinhado ao período

         // forward: SEMPRE a partir de B, no MESMO nível de B
         datetime tf = (datetime)((long)legs[L].t2 + snap);
         int n=ArraySize(marks)+1; ArrayResize(marks,n);
         marks[n-1].t=tf; marks[n-1].ratio=rr; marks[n-1].leg_id=legs[L].id; marks[n-1].forward=true; marks[n-1].priceB=legs[L].p2;

         // backward (opcional), no MESMO nível do pivô B
         if(InpTimeBothDirections){
            datetime tb = (datetime)((long)legs[L].t2 - snap);
            n=ArraySize(marks)+1; ArrayResize(marks,n);
            marks[n-1].t=tb; marks[n-1].ratio=rr; marks[n-1].leg_id=legs[L].id; marks[n-1].forward=false; marks[n-1].priceB=legs[L].p2;
         }
      }
   }
   marks_count=ArraySize(marks);
}

// ========================= Unificação ================================
void BuildUnifiedFromLegacy(const LineItem &price[], int pn,
                            const TimeItem &tarr[],  int tn,
                            FibItem &out[], int &out_count,
                            int &idx_price[], int &idx_time[])
{
   ArrayResize(out, 0); out_count = 0;
   ArrayResize(idx_price, 0);
   ArrayResize(idx_time,  0);

   // preço
   for(int i=0;i<pn;i++){
      FibItem it;
      it.kind=FIBK_PRICE; it.ratio=price[i].ratio; it.leg_id=price[i].leg_id;
      it.price=price[i].price; it.is_expansion=price[i].is_expansion; it.is_up=price[i].is_up; it.tB=price[i].tB;
      it.t=0; it.forward=false;
      int n=ArraySize(out)+1; ArrayResize(out,n); out[n-1]=it;
      int p=ArraySize(idx_price)+1; ArrayResize(idx_price,p); idx_price[p-1]=n-1;
   }
   // tempo (no preço do pivô B)
   for(int i=0;i<tn;i++){
      FibItem it;
      it.kind=FIBK_TIME; it.ratio=tarr[i].ratio; it.leg_id=tarr[i].leg_id;
      it.t=tarr[i].t; it.forward=tarr[i].forward;
      it.price=tarr[i].priceB; it.is_expansion=false; it.is_up=false; it.tB=0;
      int n=ArraySize(out)+1; ArrayResize(out,n); out[n-1]=it;
      int p=ArraySize(idx_time)+1; ArrayResize(idx_time,p); idx_time[p-1]=n-1;
   }
   out_count = ArraySize(out);
}

// ========================= Cluster (linhas) =========================
void SortPricesWithIndex(const FibItem &all[], const int &view_idx[], int n, double &P[], int &idx_sorted[])
{
   ArrayResize(P,n); ArrayResize(idx_sorted,n);
   for(int k=0;k<n;k++){ idx_sorted[k]=view_idx[k]; P[k]=all[view_idx[k]].price; }
   for(int a=0;a<n-1;a++){
      int best=a;
      for(int b=a+1;b<n;b++) if(P[b]<P[best]) best=b;
      if(best!=a){
         double tp=P[a]; P[a]=P[best]; P[best]=tp;
         int ti=idx_sorted[a]; idx_sorted[a]=idx_sorted[best]; idx_sorted[best]=ti;
      }
   }
}
bool GetVisibleTimeRange(const datetime &time[], int total, datetime &t_left, datetime &t_right) // shim
{
   double pmin,pmax; return GetVisibleWindow(time,total,t_left,t_right,pmin,pmax);
}
void ComputeClusterMembershipAndZones(const double &P[], const int &idx_sorted[], int n,
                                      double range, int min_lines,
                                      bool make_zones, double rect_thickness,
                                      bool &member_all[],
                                      PRZ &zones[], int &zone_count)
{
   for(int i=0;i<ArraySize(member_all);i++) member_all[i]=false;
   ArrayResize(zones,0); zone_count=0;
   if(n<=0 || range<=0.0 || min_lines<=1) return;

   const double h   = range*0.5;
   const double eps = _Point*0.1;

   struct Cand { double low, high, center; int count; };
   Cand cand[]; ArrayResize(cand,0);

   for(int i=0;i<n;i++)
   {
      const double L = P[i] - h;
      const double R = P[i] + h;
      const int s = LowerBound(P, n, L - eps);
      const int e = UpperBound(P, n, R + eps);
      const int cnt = e - s;

      if(cnt >= min_lines)
      {
         for(int k=s;k<e;k++){
            const int all_idx = idx_sorted[k];
            if(all_idx>=0 && all_idx<ArraySize(member_all)) member_all[all_idx]=true;
         }

         if(make_zones){
            const double c = P[i];
            Cand w; w.low = c-h; w.high = c+h; w.center=c; w.count=cnt;
            int m=ArraySize(cand)+1; ArrayResize(cand,m); cand[m-1]=w;
         }
      }
   }

   if(!make_zones || ArraySize(cand)==0) return;

   for(int a=0;a<ArraySize(cand)-1;a++){
      int best=a;
      for(int b=a+1;b<ArraySize(cand);b++) if(cand[b].low < cand[best].low) best=b;
      if(best!=a){ Cand t=cand[a]; cand[a]=cand[best]; cand[best]=t; }
   }

   bool open=false; Cand best;
   for(int i=0;i<ArraySize(cand);i++){
      if(!open){ best=cand[i]; open=true; continue; }
      bool overlap = (cand[i].low <= best.high && cand[i].high >= best.low);
      if(overlap){
         if(cand[i].count > best.count) best=cand[i];
      }else{
         PRZ z; z.center=best.center;
         double half=(rect_thickness>0? rect_thickness*0.5 : h);
         z.low=z.center-half; z.high=z.center+half; z.count=best.count;
         int m=ArraySize(zones)+1; ArrayResize(zones,m); zones[m-1]=z;
         best=cand[i];
      }
   }
   if(open){
      PRZ z; z.center=best.center;
      double half=(rect_thickness>0? rect_thickness*0.5 : h);
      z.low=z.center-half; z.high=z.center+half; z.count=best.count;
      int m=ArraySize(zones)+1; ArrayResize(zones,m); zones[m-1]=z;
   }
   zone_count=ArraySize(zones);
}

// ========================= Desenho =========================
int DrawClusterLines(const FibItem &all[], const int &view_idx[], int n,
                     const bool &member_all[],
                     const datetime &time[], int total)
{
   int drawn=0;
   datetime tL=0,tR=0; double pmin=0,pmax=0;
   if(!GetVisibleWindow(time,total,tL,tR,pmin,pmax)){
      bool series=IsSeries(time,total);
      int idxLeft = (series? total-1 : 0);
      int idxRight = (series? 0 : total-1);
      int ps=PeriodSeconds(); if(ps<=0) ps=60;
      tL = time[idxLeft];
      tR = (datetime)((long)time[idxRight] + ps*InpRightTextMarginBars);
   }

    datetime segL = tL;
    datetime segR = tR;
    if(g_dw_active && g_dw_time_left<g_dw_time_right){
       segL = g_dw_time_left;
       segR = g_dw_time_right;
    }
    if(segL==segR){
       int ps=PeriodSeconds(); if(ps<=0) ps=60;
       segR = (datetime)((long)segR + ps);
    }
    datetime labelLeft = (segL!=0? segL : tL);
    datetime labelRight = (segR!=0? segR : tR);
    int lineWidth = MathMax(1, InpFibLineWidth);

   for(int k=0;k<n;k++){
      int i=view_idx[k];
      if(i<0 || i>=ArraySize(member_all)) continue;
      if(!member_all[i]) continue;

      color col = (all[i].is_expansion ? InpExpandLineColor : InpRetraceLineColor);
      string ln = G_PREF_LINE+IntegerToString(drawn);
      UpsertPriceSegment(ln, segL, segR, all[i].price, col, lineWidth);

      string lbl = BuildLineLabelText(all[i]);
      MaintainPriceLabels(drawn, all[i].price, lbl, col, labelLeft, labelRight);
      drawn++;
   }

   for(int i=drawn;i<g_prev_line_count;i++){
      ObjectDelete(ChartID(), G_PREF_LINE+IntegerToString(i));
      string base = G_PREF_LBL + IntegerToString(i);
      ObjectDelete(ChartID(), base + "_R");
      ObjectDelete(ChartID(), base + "_L");
   }
   g_prev_line_count = drawn;
   return drawn;
}
void DrawPriceOverlayAll(const FibItem &all[], const int &view_idx[], int n, bool enabled,
                         const datetime &time[], int total)
{
   int drawn=0;
   if(enabled){
      datetime tL=0,tR=0; double pmin=0,pmax=0;
      if(!GetVisibleWindow(time,total,tL,tR,pmin,pmax)){
         bool series=IsSeries(time,total);
         int idxLeft = (series? total-1 : 0);
         int idxRight= (series? 0 : total-1);
         int ps=PeriodSeconds(); if(ps<=0) ps=60;
         tL = time[idxLeft];
         tR = (datetime)((long)time[idxRight] + ps*InpRightTextMarginBars);
      }
      datetime segL = tL;
      datetime segR = tR;
      if(g_dw_active && g_dw_time_left<g_dw_time_right){
         segL = g_dw_time_left;
         segR = g_dw_time_right;
      }
      if(segL==segR){
         int ps=PeriodSeconds(); if(ps<=0) ps=60;
         segR = (datetime)((long)segR + ps);
      }
      for(int k=0;k<n;k++){
         int i=view_idx[k];
         string nm = G_PREF_RAW + IntegerToString(drawn++);
         UpsertPriceSegment(nm, segL, segR, all[i].price, clrSilver, 1, STYLE_DOT, true);
      }
   }
   for(int i=drawn;i<g_prev_raw_count;i++) ObjectDelete(ChartID(), G_PREF_RAW + IntegerToString(i));
   g_prev_raw_count = drawn;
}
void DrawPRZZones(const PRZ &zones[], int n, const datetime &time[], int total)
{
   datetime tL=0,tR=0; double pmin=0,pmax=0;
   if(!GetVisibleWindow(time,total,tL,tR,pmin,pmax)){
      bool series=IsSeries(time,total);
      int ps=PeriodSeconds(); if(ps<=0) ps=60;
      tL = time[series? total-1 : 0];
      tR = (datetime)((long)time[series? 0 : total-1] + ps*InpRightTextMarginBars);
   }

   int drawn=0;
   if(InpDrawPRZRectangles){
      for(int i=0;i<n;i++){
         string nm = G_PREF_PRZ + IntegerToString(drawn);
         UpsertPRZRect(nm, tL, tR, zones[i].low, zones[i].high, InpPRZRectColor, InpPRZRectBorderWidth);
         if(InpShowLabels){
            string tn = G_PREF_PRZ + "LBL_" + IntegerToString(drawn);
            UpsertText(tn, tR, zones[i].high, StringFormat("PRZ (n=%d)", zones[i].count), clrWhite, 8);
         }
         drawn++;
      }
   }
   for(int i=drawn;i<g_prev_prz_count;i++){
      ObjectDelete(ChartID(), G_PREF_PRZ + IntegerToString(i));
      ObjectDelete(ChartID(), G_PREF_PRZ + "LBL_" + IntegerToString(i));
   }
   g_prev_prz_count = drawn;
}
void DrawTimeMarks(const FibItem &all[], const int &view_idx[], int n)
{
   int drawn_dot=0, drawn_vl=0;
   for(int i=0;i<n;i++){
      int idx=view_idx[i];
      string nm = G_PREF_TF + "DOT_" + IntegerToString(drawn_dot++);
      UpsertText(nm, all[idx].t, all[idx].price, ".", InpTimeDotColor, InpTimeDotFontSize);
      if(InpShowTimeVLines){
         string vl = G_PREF_TFVL + IntegerToString(drawn_vl++);
         UpsertVLine(vl, all[idx].t, InpTimeDotColor, 1, true);
      }
   }
   for(int i=drawn_dot;i<g_prev_tf_count;i++) ObjectDelete(ChartID(), G_PREF_TF + "DOT_" + IntegerToString(i));
   for(int i=drawn_vl;i<g_prev_tfvl_count;i++) ObjectDelete(ChartID(), G_PREF_TFVL + IntegerToString(i));
   g_prev_tf_count   = drawn_dot;
   g_prev_tfvl_count = drawn_vl;
}

// ========================= Debug Helpers =========================
void ClearDebugPriceObjects(const string &prefLine,const string &prefLabel,int &prevCount)
{
   for(int i=0;i<prevCount;i++){
      ObjectDelete(ChartID(), prefLine + IntegerToString(i));
      ObjectDelete(ChartID(), prefLabel + IntegerToString(i));
   }
   prevCount=0;
}

void DrawDebugPriceSubset(const LineItem &source[], int total, bool wantExpansion, int limit,
                          color lineColor, const datetime &time[], int rates_total,
                          const string &prefLine, const string &prefLabel, int &prevCount)
{
   limit = MathMax(0, limit);
   if(limit==0 || total<=0){
      ClearDebugPriceObjects(prefLine, prefLabel, prevCount);
      return;
   }

   datetime tL=0,tR=0; double pmin=0,pmax=0;
   if(!GetVisibleWindow(time,rates_total,tL,tR,pmin,pmax)){
      bool series=IsSeries(time,rates_total);
      int idxLeft = (series? rates_total-1 : 0);
      int idxRight= (series? 0 : rates_total-1);
      int ps=PeriodSeconds(); if(ps<=0) ps=60;
      tL = time[idxLeft];
      tR = (datetime)((long)time[idxRight] + ps*InpRightTextMarginBars);
   }

   datetime segL = tL;
   datetime segR = tR;
   if(g_dw_active && g_dw_time_left<g_dw_time_right){
      segL = g_dw_time_left;
      segR = g_dw_time_right;
   }
   if(segL==segR){
      int ps=PeriodSeconds(); if(ps<=0) ps=60;
      segR = (datetime)((long)segR + ps);
   }

   int drawn=0;
   for(int i=0;i<total && drawn<limit;i++)
   {
      if(source[i].is_expansion != wantExpansion) continue;
      string nm = prefLine + IntegerToString(drawn);
      UpsertPriceSegment(nm, segL, segR, source[i].price, lineColor, MathMax(1, InpFibLineWidth), STYLE_DASHDOTDOT);
      string lbl = prefLabel + IntegerToString(drawn);
      string text = StringFormat("DBG %s (leg %d)", RatioTag(source[i].ratio), source[i].leg_id);
      UpsertText(lbl, tR, source[i].price, text, lineColor, 8);
      drawn++;
   }

   for(int i=drawn;i<prevCount;i++){
      ObjectDelete(ChartID(), prefLine + IntegerToString(i));
      ObjectDelete(ChartID(), prefLabel + IntegerToString(i));
   }
   prevCount=drawn;
}

void DrawDebugTimeSubset(const TimeItem &source[], int total, int limit,
                         const datetime &time[], int rates_total,
                         const string &prefDot, const string &prefVLine,
                         int &prevDots, int &prevVLines)
{
   limit = MathMax(0, limit);
   if(limit==0 || total<=0){
      for(int i=0;i<prevDots;i++) ObjectDelete(ChartID(), prefDot + IntegerToString(i));
      for(int i=0;i<prevVLines;i++) ObjectDelete(ChartID(), prefVLine + IntegerToString(i));
      prevDots=0; prevVLines=0;
      return;
   }

   int drawn=0;
   color dbgColor = clrLime;
   for(int i=0;i<total && drawn<limit;i++)
   {
      string nm = prefDot + IntegerToString(drawn);
      string text = StringFormat("DBG T %.3f %s", source[i].ratio, (source[i].forward? "F" : "B"));
      UpsertText(nm, source[i].t, source[i].priceB, text, dbgColor, InpTimeDotFontSize);

      string vl = prefVLine + IntegerToString(drawn);
      UpsertVLine(vl, source[i].t, dbgColor, 1, true);
      drawn++;
   }

   for(int i=drawn;i<prevDots;i++) ObjectDelete(ChartID(), prefDot + IntegerToString(i));
   for(int i=drawn;i<prevVLines;i++) ObjectDelete(ChartID(), prefVLine + IntegerToString(i));
   prevDots = drawn;
   prevVLines = drawn;
}

// ========================= Contadores =========================
bool MatchesPct(double ratio, double pct){ return MathAbs(ratio*100.0 - pct) <= 0.15; }
void CountPriceSubtypes(const FibItem &all[], int allN){ g_R_all=g_X_all=0; for(int i=0;i<allN;i++){ if(all[i].kind!=FIBK_PRICE) continue; if(all[i].is_expansion) g_X_all++; else g_R_all++; } }
void CapturePivotStats(const Pivot &piv[], int piv_count)
{
   g_pivot_total = piv_count;
   g_pivot_tops = 0;
   g_pivot_bottoms = 0;
   for(int i=0;i<piv_count;i++){
      if(piv[i].is_high) g_pivot_tops++;
      else               g_pivot_bottoms++;
   }
}

// ========================= Lifecycle =========================
int OnInit()
{
   if(!ParseRatiosTo(InpFibRatios, g_fib_ratios)){ Print("Fibo: não foi possível interpretar as razões de PREÇO."); return INIT_FAILED; }
   ParseRatiosTo(InpTimeFibRatios, g_time_ratios);
   ClearByPrefix("FCZ");

   // cria handle do ZigZag (única fonte de pivôs)
   g_zz_handle = iCustom(_Symbol, _Period, "ZigZag", InpZZ_Depth, InpZZ_Deviation, InpZZ_Backstep);
   if(g_zz_handle==INVALID_HANDLE){
      Print("Falha ao criar ZigZag via iCustom. Verifique se o indicador padrão 'ZigZag' está disponível.");
      return INIT_FAILED;
   }

   if(InpShowZigZagSecondary){
      g_zz2_handle = iCustom(_Symbol, _Period, "ZigZag", InpZZ2_Depth, InpZZ2_Deviation, InpZZ2_Backstep);
      if(g_zz2_handle==INVALID_HANDLE){
         Print("Aviso: ZigZag secundário não pôde ser criado (verifique indicador padrão).");
      }
   }else{
      g_zz2_handle = INVALID_HANDLE;
   }

   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason){
   ClearByPrefix("FCZ");
   if(g_zz_handle!=INVALID_HANDLE) IndicatorRelease(g_zz_handle);
    if(g_zz2_handle!=INVALID_HANDLE) IndicatorRelease(g_zz2_handle);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   g_dbg_prints=0;
   if(rates_total<2) return rates_total;

   // 1) Pivôs & Pernas — conforme a FONTE escolhida
   Pivot piv[]; int pc = CollectPivots_ZZ(high,low,time,rates_total, InpPivotScanLookbackBars, piv);
   CapturePivotStats(piv, pc);

   LegSeg legs[]; int leg_count=0;
   BuildLegsFromPivots(piv, pc, InpLegsToUse, legs, leg_count);
   g_leg_total = leg_count;
   DrawLegs(legs,leg_count);
   const int primary_overlay_skip   = MathMax(0, InpZigZagPrimaryStartOffset);
   const int secondary_overlay_skip = MathMax(0, InpZigZagSecondaryStartOffset);

   DrawZigZagOverlay(g_zz_handle,
                     InpShowZigZagPrimary,
                     G_PREF_ZZ1, g_prev_zz1_count,
                     InpZigZagPrimaryColor, InpZigZagPrimaryWidth,
                     high, low, time, rates_total, InpPivotScanLookbackBars, primary_overlay_skip,
                     InpShowZigZagPrimaryPivots,
                     G_PREF_ZZ1_PIV, g_prev_zz1_piv_count,
                     InpZigZagPrimaryPivotColor, InpZigZagPrimaryPivotSize);
   DrawZigZagOverlay(g_zz2_handle,
                     InpShowZigZagSecondary,
                     G_PREF_ZZ2, g_prev_zz2_count,
                     InpZigZagSecondaryColor, InpZigZagSecondaryWidth,
                     high, low, time, rates_total, InpPivotScanLookbackBars, secondary_overlay_skip,
                     InpShowZigZagSecondaryPivots,
                     G_PREF_ZZ2_PIV, g_prev_zz2_piv_count,
                     InpZigZagSecondaryPivotColor, InpZigZagSecondaryPivotSize);

   // 2) Linhas PREÇO + TEMPO
   BuildAllPriceLines(legs,leg_count, g_price_all, g_price_total);
   if(InpShowTimeFibs){ BuildTimeMarks(legs, leg_count, g_time_all, g_time_total); }
   else{ ArrayResize(g_time_all,0); g_time_total=0; }

   // 3) Base única + views
   BuildUnifiedFromLegacy(g_price_all, g_price_total,
                          g_time_all,  g_time_total,
                          g_all, g_all_total,
                          g_view_price, g_view_time);

   bool needDailyWindow = (InpUseDailyWindow || InpShowDailyWindowInfo);
   double dwLow=0.0, dwHigh=0.0, dwMid=0.0, dwAtr=0.0;
   datetime dwTStart=0, dwTEnd=0;
   int dwFlags = DW_FALLBACK_NONE;
   bool dwCenterMA=false;
   bool dwOk=false;
   if(needDailyWindow){
      dwOk = GetDailyWindowBounds(time, high, low, rates_total,
                                  dwLow, dwHigh, dwMid, dwAtr, dwFlags,
                                  dwTStart, dwTEnd, dwCenterMA);
      ShowDailyWindowFallbackNotice(dwFlags);
   }else{
      ShowDailyWindowFallbackNotice(DW_FALLBACK_NONE);
   }
   g_dw_active = (dwOk && InpUseDailyWindow);
   g_dw_time_left  = (g_dw_active? dwTStart : 0);
   g_dw_time_right = (g_dw_active? dwTEnd   : 0);
   double dwSpan = (dwOk? dwHigh-dwLow : 0.0);
   if(InpUseDailyWindow && dwOk){
      ApplyDailyWindowFilter(g_all, g_view_price, dwLow, dwHigh);
   }
   ShowDailyWindowInfo(InpShowDailyWindowInfo, dwOk, dwLow, dwHigh, dwMid, dwAtr, dwFlags, dwSpan, dwCenterMA);

   CountPriceSubtypes(g_all, g_all_total);

   // 4) PREÇO — modo
   if(InpPriceMode==PRICE_RAW)
   {
      int drawn=0;
      datetime tL=0,tR=0; double pmin=0,pmax=0;
      if(!GetVisibleWindow(time,rates_total,tL,tR,pmin,pmax)){
         bool series=IsSeries(time,rates_total);
         int idxLeft = (series? rates_total-1 : 0);
         int idxRight= (series? 0 : rates_total-1);
         int ps=PeriodSeconds(); if(ps<=0) ps=60;
         tL = time[idxLeft];
         tR = (datetime)((long)time[idxRight] + ps*InpRightTextMarginBars);
      }

      datetime segL = tL;
      datetime segR = tR;
      if(g_dw_active && g_dw_time_left<g_dw_time_right){
         segL = g_dw_time_left;
         segR = g_dw_time_right;
      }
      if(segL==segR){
         int ps=PeriodSeconds(); if(ps<=0) ps=60;
         segR = (datetime)((long)segR + ps);
      }
      datetime labelLeft = (segL!=0? segL : tL);
      datetime labelRight = (segR!=0? segR : tR);
      int lineWidth = MathMax(1, InpFibLineWidth);

      for(int k=0;k<ArraySize(g_view_price);k++){
         int i=g_view_price[k];
         color col=(g_all[i].is_expansion ? InpExpandLineColor : InpRetraceLineColor);
         string ln=G_PREF_LINE+IntegerToString(drawn);
         UpsertPriceSegment(ln, segL, segR, g_all[i].price, col, lineWidth);
         string lbl = BuildLineLabelText(g_all[i]);
         MaintainPriceLabels(drawn, g_all[i].price, lbl, col, labelLeft, labelRight);
         drawn++;
      }
      for(int i=drawn;i<g_prev_line_count;i++){
         ObjectDelete(ChartID(), G_PREF_LINE+IntegerToString(i));
         string base = G_PREF_LBL + IntegerToString(i);
         ObjectDelete(ChartID(), base + "_R");
         ObjectDelete(ChartID(), base + "_L");
      }
      g_prev_line_count=drawn;

      ClearPRZObjects();
      ClearShadowClusterRects();
      ArrayResize(g_prz_shadow_flag,0);
      DrawPriceOverlayAll(g_all, g_view_price, ArraySize(g_view_price), false, time, rates_total);
      g_visible_cluster_lines = drawn;
      g_prz_count = 0;
   }
   else // PRICE_CLUSTER
   {
     double atrD1=0.0; bool okATR = GetATR_D1(InpATR_D1_Periods, atrD1);
     if(!okATR || atrD1<=0.0){
        double sumR=0.0; int N=MathMin(200,rates_total);
        for(int i=0;i<N;i++) sumR += (high[i]-low[i]);
        atrD1 = (N>0? sumR/N : 0.0);
     }
     double cluster_range = atrD1 * (InpClusterRangePctATR/100.0);
     double rect_thick    = (InpPRZRectUseCustomPctATR ? (atrD1 * (InpPRZRectThicknessPctATR/100.0)) : cluster_range);

     int n = ArraySize(g_view_price);
     double P[]; int idx_sorted[];
     SortPricesWithIndex(g_all, g_view_price, n, P, idx_sorted);

     bool member_all[]; ArrayResize(member_all, g_all_total);
     ComputeClusterMembershipAndZones(P, idx_sorted, n,
                                      cluster_range, InpClusterMinLines,
                                      InpDrawPRZRectangles, rect_thick,
                                      member_all, g_prz, g_prz_count);

     EvaluateShadowClusters(time, open, high, low, close, tick_volume, rates_total);
     g_visible_cluster_lines = DrawClusterLines(g_all, g_view_price, n, member_all, time, rates_total);
     DrawPRZZones(g_prz, g_prz_count, time, rates_total);
     DrawShadowClusterRects(time, rates_total);
     DrawPriceOverlayAll(g_all, g_view_price, n, InpDebugOverlayAllPriceLines, time, rates_total);

     if(InpDebugLog){
      Dbg(StringFormat("[Fibo][%s] Src=ZZ  ATR(1D,p=%d)=%.5f  Range=%.2f%%  MinLines=%d  PRZ=%d  ClusterLines=%d  LinesTot=%d",
           _Symbol,
            InpATR_D1_Periods, atrD1, InpClusterRangePctATR, InpClusterMinLines,
            g_prz_count, g_visible_cluster_lines, n));
     }
   }

   // 5) TEMPO — pontos + vlines (no mesmo nível do pivô B)
   if(InpShowTimeFibs){
      DrawTimeMarks(g_all, g_view_time, ArraySize(g_view_time));
   }else{
      for(int i=0;i<g_prev_tf_count;i++)    ObjectDelete(ChartID(), G_PREF_TF   + "DOT_" + IntegerToString(i));
      for(int i=0;i<g_prev_tfvl_count;i++) ObjectDelete(ChartID(), G_PREF_TFVL +          IntegerToString(i));
      g_prev_tf_count=0; g_prev_tfvl_count=0;
   }

   // 5.1) Debug overlays independent das janelas/filtros
   DrawDebugPriceSubset(g_price_all, g_price_total, false, InpDebugLastRetractions,
                        InpRetraceLineColor, time, rates_total,
                        G_PREF_DBG_RET, G_PREF_DBG_RET_LBL, g_prev_dbg_ret_count);
   DrawDebugPriceSubset(g_price_all, g_price_total, true, InpDebugLastExpansions,
                        InpExpandLineColor, time, rates_total,
                        G_PREF_DBG_EXP, G_PREF_DBG_EXP_LBL, g_prev_dbg_exp_count);
   DrawDebugTimeSubset(g_time_all, g_time_total, InpDebugLastTimeMarks,
                       time, rates_total,
                       G_PREF_DBG_TIME, G_PREF_DBG_TIME_VL,
                       g_prev_dbg_time_dot_count, g_prev_dbg_time_vl_count);

   // 6) RESUMO (visor)
   if(InpShowSummary)
   {
      string ln1 = StringFormat(
         "PRICE  Linhas:%d  EmCluster:%d  PRZs:%d  Range=%.2f%% ATR(1D,p=%d)",
         ArraySize(g_view_price), g_visible_cluster_lines, g_prz_count, InpClusterRangePctATR, InpATR_D1_Periods
      );
      string ln2 = StringFormat("PRICE  R:%d  X:%d  MinLinhas:%d  Pernas:%d  Topos:%d  Fundos:%d  Skip:%d",
                                g_R_all, g_X_all, InpClusterMinLines, g_leg_total, g_pivot_tops, g_pivot_bottoms, InpPivotStartOffset);
      string ln3 = StringFormat(
         "TIME   Marcas:%d  VLines:%s  (ambas direções=%s  base=%s)   Pivôs=ZigZag",
         ArraySize(g_view_time), (InpShowTimeVLines? "sim":"não"),
         (InpTimeBothDirections? "sim":"não"), (InpTimeAllLegs? "todas":"base")
      );

      string text = (InpSummaryShowBreakdown ? (ln1+"\n"+ln2+"\n"+ln3) : (ln1+"\n"+ln3));
      ShowSummaryLabel(text);
   }else{
      ClearSummaryLabel();
   }

   return rates_total;
}
