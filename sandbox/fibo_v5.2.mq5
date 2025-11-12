#property copyright "2025"
#property link      ""
#property version   "3.25"
#property strict
#property indicator_chart_window
#property indicator_plots 0

// ========================= Inputs =========================

// -- Enumeradores relacionados aos inputs --
enum ENUM_PRICE_MODE { PRICE_CLUSTER=0, PRICE_RAW=1 };
enum ENUM_LABEL_DISPLAY_MODE { LABEL_MODE_NORMAL=0, LABEL_MODE_DEBUG=1 };
enum ENUM_PRICE_LABEL_TEXT_MODE { PRICE_LABEL_TEXT_CLASSIC=0, PRICE_LABEL_TEXT_TRADING=1 };

input group   "ZigZag Primário";
input int      InpZZ_Depth                   = 12;    // ZigZag: Depth
input int      InpZZ_Deviation               = 5;     // ZigZag: Deviation
input int      InpZZ_Backstep                = 3;     // ZigZag: Backstep
input bool     InpShowZigZagPrimary          = false; // overlay: desenhar linhas?
input color    InpZigZagPrimaryColor         = clrDodgerBlue;
input int      InpZigZagPrimaryWidth         = 1;
input color    InpZigZagPrimaryPivotColor    = clrDodgerBlue;
input int      InpZigZagPrimaryPivotSize     = 1;
input int      InpZigZagPrimaryStartOffset   = 0;     // ignora X segmentos recentes (cálculo/overlay)

input group   "ZigZag Secundário";
input bool     InpShowZigZagSecondary        = false; // desenha 2º ZigZag?
input int      InpZZ2_Depth                  = 34;    // ZigZag2: Depth
input int      InpZZ2_Deviation              = 8;     // ZigZag2: Deviation
input int      InpZZ2_Backstep               = 5;     // ZigZag2: Backstep
input color    InpZigZagSecondaryColor       = clrMediumOrchid;
input int      InpZigZagSecondaryWidth       = 1;
input color    InpZigZagSecondaryPivotColor  = clrMediumOrchid;
input int      InpZigZagSecondaryPivotSize   = 2;
input int      InpZigZagSecondaryStartOffset = 0;     // ignora X segmentos recentes (cálculo/overlay)

input group   "Pivôs e Pernas";
input int      InpPivotScanLookbackBars  = 500;   // quantas barras recentes escanear
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
input bool     InpUseDailyWindow         = true;   // liga/desliga a janela diária
input double   InpDailyWindowSpanPctATR  = 100.0;  // altura = % do ATR(D1)
input double   InpDailyWindowWidthDays   = 1.0;    // largura = múltiplos do período D1

const double   G_DW_RANGE_MULTIPLIER     = 1.0;
const int      G_DW_CENTER_MA_PERIOD     = 20;
const int      G_DW_EXTEND_BARS          = 12;
const int      G_DW_BOUND_WIDTH          = 1;
const color    G_DW_BOUND_COLOR          = clrDarkSlateGray;
const color    G_DW_CENTER_COLOR         = clrGold;
const bool     G_DW_SHOW_INFO            = true;
const bool     G_DW_SHOW_BOUNDS          = true;
const bool     G_DW_SHOW_CENTER_LINE     = true;

input group   "Clusters";
input int      InpATR_D1_Periods         = 14;     // ATR(1D) período (média de x dias)
input double   InpClusterRangePctATR     = 0.3;   // ESPESSURA do cluster = % do ATR(1D)
input int      InpClusterMinLines        = 4;     // mínimo de linhas para existir cluster (Recomendado)

input group   "Exibição de Preço";
input ENUM_PRICE_MODE InpPriceMode       = PRICE_CLUSTER; // padrão = LINHAS em CLUSTER
input ENUM_LABEL_DISPLAY_MODE InpPriceLabelMode = LABEL_MODE_DEBUG; // modo de exibição dos rótulos
input int      InpFibLineWidth           = 1;
input color    InpRetraceLineColor       = clrDeepSkyBlue; // R
input color    InpExpandLineColor        = clrOrangeRed;   // X
input bool     InpShowLabels             = true;           // rótulos (ratio) nas linhas
input bool     InpLabelsMirrorLeft       = true;           // duplicar rótulos no lado esquerdo
input bool     InpLabelShowLeg           = true;           // incluir id da perna no rótulo
input ENUM_PRICE_LABEL_TEXT_MODE InpPriceLabelTextMode = PRICE_LABEL_TEXT_CLASSIC; // conteúdo dos rótulos

input group   "Tempo";
input bool     InpShowTimeFibs           = false;        // liga/desliga marcas de tempo
input bool     InpShowTimeVLines         = true;         // além do ponto, desenhar VLINE
input color    InpTimeDotColor           = clrSilver;
input int      InpTimeDotFontSize        = 8;

input group   "PRZ";
input bool     InpDrawPRZRectangles      = true;     // OFF = padrão (apenas linhas-cluster)
input bool     InpPRZRectUseCustomPctATR = false;     // ON = usar espessura custom abaixo
input double   InpPRZRectThicknessPctATR = 5.0;      // espessura do retângulo (% do ATR 1D) quando custom ON
input color    InpPRZRectColor           = clrAliceBlue;
input int      InpPRZRectBorderWidth     = 1;
input string   InpPRZLabelFormat         = "PRZ (n=%d)";
input color    InpPRZLabelColor          = clrWhite;
input bool     InpPRZForceShow           = false;    // mostra PRZs mesmo abaixo do mínimo

input group   "Sombras / Volume";
input bool     InpHighlightShadowClusters   = true;   // destaca clusters com sombras volumosas?
input int      InpShadowVolumeMAPeriod      = 20;     // média móvel de volume (tick) em X períodos
input double   InpShadowVolumeMultiplier    = 1.5;    // volume da barra >= multiplicador * média
input double   InpShadowEqualityTolerance   = 0.05;   // tolerância (0-1) p/ considerar sombras iguais
input color    InpShadowUpperColor          = clrTomato;      // cor quando sombra superior domina
input color    InpShadowLowerColor          = clrDodgerBlue;  // cor quando sombra inferior domina

input group   "Diagnóstico";
input int      InpRightTextMarginBars    = 6;      // margem à direita (texto)
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
   DW_FALLBACK_ATR     = 2,
   DW_FALLBACK_EMPTY   = 4,
   DW_FALLBACK_CACHE   = 8
};

// PRZ (opcional)
struct PRZ { double low; double high; int count; double center; }; // count = níveis únicos no cluster

// ========================= Globais =========================
double          g_fib_ratios[];
double          g_time_ratios[];

string          G_PREF_LINE = "FCZLINE_";
string          G_PREF_LBL  = "FCZLBL_";
string          G_PREF_LEG  = "FCZLEG_";
string          G_PREF_TF   = "FCZTF_";     // pontos de tempo (•)
string          G_PREF_TFVL = "FCZTFVL_";   // vlines de tempo
string          G_PREF_PRZ  = "FCZPRZ_";
string          G_PREF_ZZ1  = "FCZZPRI_";
string          G_PREF_ZZ2  = "FCZZSEC_";
string          G_PREF_SHADOW = "FCZSHADOW_";
string          G_PREF_ZZ1_PIV = "FCZZPIV1_";
string          G_PREF_ZZ2_PIV = "FCZZPIV2_";
string          G_PREF_WARN_DW = "FCZWARN_DW";
string          G_PREF_DW_INFO = "FCZDWINFO";
string          G_PREF_DW_BOUND_TOP = "FCZDW_BOUND_TOP";
string          G_PREF_DW_BOUND_BOTTOM = "FCZDW_BOUND_BOTTOM";
string          G_PREF_DW_BOUND_CENTER = "FCZDW_BOUND_CENTER";
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
ENUM_LABEL_DISPLAY_MODE g_prev_label_mode = LABEL_MODE_NORMAL;

bool            g_dw_active = false;
datetime        g_dw_time_left = 0;
datetime        g_dw_time_right = 0;
int             g_dw_center_ma_handle = INVALID_HANDLE;
int             g_dw_center_ma_period = 0;
bool            g_dw_cache_valid = false;
double          g_dw_cache_low = 0.0;
double          g_dw_cache_high = 0.0;
double          g_dw_cache_mid = 0.0;
double          g_dw_cache_atr = 0.0;
datetime        g_dw_cache_t_start = 0;
datetime        g_dw_cache_t_end = 0;
bool            g_dw_cache_center_from_ma = false;
bool            g_dw_cache_used_abs_height = false;
bool            g_dw_cache_used_abs_width = false;
int             g_dw_cache_flags = DW_FALLBACK_NONE;

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

// price label slots (stable ids → object names)
string          g_label_slot_identity[];
bool            g_label_slot_used[];

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
                          bool &out_center_from_ma,
                          bool &out_used_abs_height, bool &out_used_abs_width)
{
   fallback_flags = DW_FALLBACK_NONE;
   out_center_from_ma = false;
   out_used_abs_height = false;
   out_used_abs_width  = false;

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
   int centerPeriod = MathMax(0, G_DW_CENTER_MA_PERIOD);
   EnsureDailyWindowCenterMAHandle(centerPeriod);
   if(centerPeriod>0){
      double maCenter=0.0;
      if(TryGetDailyWindowCenterMA(maCenter)){
         center = maCenter;
         out_center_from_ma = true;
      }else if(InpDebugLog){
         int calc = (g_dw_center_ma_handle!=INVALID_HANDLE? BarsCalculated(g_dw_center_ma_handle) : -1);
         Dbg(StringFormat("[DW] MA diária indisponível (p=%d handle=%d calc=%d)",
                         centerPeriod, g_dw_center_ma_handle, calc));
      }
   }

   double span=0.0;
   out_used_abs_height = false;
   double pct = MathMax(0.01, InpDailyWindowSpanPctATR);
   double spanAtr = atrD1 * (pct/100.0);
   double mult = MathMax(1.0, G_DW_RANGE_MULTIPLIER);
   double spanRange = baseRange * mult;
   span = MathMax(spanAtr, spanRange);
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
   long widthSeconds=0;
   double widthDays = MathMax(0.1, InpDailyWindowWidthDays);
   widthSeconds = (long)MathRound(widthDays * (double)daySeconds);
   if(widthSeconds<=0) widthSeconds = daySeconds;
   long halfWidth = widthSeconds/2;
   datetime midTime = (datetime)((long)dStart + (long)(MathMax(1, daySeconds)/2));
   datetime baseStart = (datetime)((long)midTime - halfWidth);
   datetime baseEnd   = (datetime)((long)midTime + halfWidth);
   out_used_abs_width = false;
   int extendBars = MathMax(0, G_DW_EXTEND_BARS);
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
   if((flags & DW_FALLBACK_EMPTY)!=0){
      if(parts!="") parts += " + ";
      parts += "sem linhas";
   }
   if((flags & DW_FALLBACK_CACHE)!=0){
      if(parts!="") parts += " + ";
      parts += "janela anterior";
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
void ShowDailyWindowInfo(bool enabled,bool hasData,double low,double high,double mid,double atr,
                         int flags,double span,bool centerFromMA,
                         bool usedAbsHeight,bool usedAbsWidth)
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
   bool legacyAbsHints = (usedAbsHeight || usedAbsWidth);
   if(legacyAbsHints){
      // parâmetros absolutos descontinuados (mantidos apenas para compatibilidade)
   }
   string fonte = "ATR% + Range";
   if((flags & DW_FALLBACK_ATR)!=0) fonte = "RangeOnly";
   if((flags & DW_FALLBACK_PRICE)!=0) fonte += "+Fallback";
   if((flags & DW_FALLBACK_EMPTY)!=0) fonte += "+SemLinhas";
   if((flags & DW_FALLBACK_CACHE)!=0) fonte += "+Cache";
   double altura = MathMax(0.0, high-low);
   double percReal = (atr>0.0 ? (altura/atr)*100.0 : 0.0);
   double percCfg  = MathMax(0.0, InpDailyWindowSpanPctATR);
   string realText = (atr>0.0 ? StringFormat("%.1f%% ATR", percReal) : "n/d");
   string cfgText  = StringFormat("SpanCfg=%.1f%% ATR  >=%.1fx Range", percCfg,
                                   MathMax(1.0, G_DW_RANGE_MULTIPLIER));
   string centerText = (centerFromMA && G_DW_CENTER_MA_PERIOD>0?
                        StringFormat("Centro=MA(%d)", G_DW_CENTER_MA_PERIOD) :
                        "Centro=mid D1");
   string widthText = StringFormat("Larg=%.2f D1", MathMax(0.1, InpDailyWindowWidthDays));
   string text = StringFormat(
      "Janela D1  Low:%.5f  High:%.5f  Centro:%.5f  Altura:%.5f  Real:%s  %s  %s  %s  Span:%.5f  ATR usado:%.5f (p=%d)  Fonte:%s",
      low, high, mid, altura, realText, centerText, cfgText, widthText, span, atr, InpATR_D1_Periods, fonte);

   if(InpDebugLog)
      Dbg(StringFormat("[DW] low=%.5f high=%.5f mid=%.5f alt=%.5f span=%.5f real=%.1f cfg=%.1f widthDays=%.2f atr=%.5f centroMA=%s fonte=%s",
                       low, high, mid, altura, span, percReal, percCfg,
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
void DrawDailyWindowBounds(bool showBounds,bool showCenter,bool hasData,
                          double low,double high,double mid,
                          datetime t_start,datetime t_end,
                          const datetime &time[],int total)
{
   const string nmTop = G_PREF_DW_BOUND_TOP;
   const string nmBot = G_PREF_DW_BOUND_BOTTOM;
   const string nmMid = G_PREF_DW_BOUND_CENTER;

   if((!showBounds && !showCenter) || !hasData){
      ObjectDelete(ChartID(), nmTop);
      ObjectDelete(ChartID(), nmBot);
      ObjectDelete(ChartID(), nmMid);
      return;
   }

   datetime left = t_start;
   datetime right = t_end;
   if(left==0 || right==0 || left==right){
      datetime tL=0,tR=0; double pmin=0,pmax=0;
      if(GetVisibleWindow(time,total,tL,tR,pmin,pmax)){
         left=tL; right=tR;
      }else{
         int ps=PeriodSeconds(); if(ps<=0) ps=60;
         datetime now=TimeCurrent();
         left = (datetime)((long)now - ps*20);
         right = (datetime)((long)now + ps*20);
      }
   }

   int width = MathMax(1, G_DW_BOUND_WIDTH);
   if(showBounds){
      UpsertPriceSegment(nmTop, left, right, high, G_DW_BOUND_COLOR, width, STYLE_DOT, true);
      UpsertPriceSegment(nmBot, left, right, low,  G_DW_BOUND_COLOR, width, STYLE_DOT, true);
   }else{
      ObjectDelete(ChartID(), nmTop);
      ObjectDelete(ChartID(), nmBot);
   }

   if(showCenter){
      UpsertPriceSegment(nmMid, left, right, mid, G_DW_CENTER_COLOR, width, STYLE_DASHDOT, true);
   }else{
      ObjectDelete(ChartID(), nmMid);
   }
}
void StoreDailyWindowCache(double low,double high,double mid,double atr,
                           datetime t_start,datetime t_end,
                           bool centerFromMA,bool usedAbsHeight,bool usedAbsWidth,
                           int flags)
{
   g_dw_cache_valid = true;
   g_dw_cache_low = low;
   g_dw_cache_high = high;
   g_dw_cache_mid = mid;
   g_dw_cache_atr = atr;
   g_dw_cache_t_start = t_start;
   g_dw_cache_t_end = t_end;
   g_dw_cache_center_from_ma = centerFromMA;
   g_dw_cache_used_abs_height = usedAbsHeight;
   g_dw_cache_used_abs_width = usedAbsWidth;
   g_dw_cache_flags = flags;
}
bool TryRestoreDailyWindowCache(double &low,double &high,double &mid,double &atr,
                                datetime &t_start,datetime &t_end,
                                bool &centerFromMA,bool &usedAbsHeight,bool &usedAbsWidth,
                                int &flags)
{
   if(!g_dw_cache_valid)
      return false;
   low = g_dw_cache_low;
   high = g_dw_cache_high;
   mid = g_dw_cache_mid;
   atr = g_dw_cache_atr;
   t_start = g_dw_cache_t_start;
   t_end = g_dw_cache_t_end;
   centerFromMA = g_dw_cache_center_from_ma;
   usedAbsHeight = g_dw_cache_used_abs_height;
   usedAbsWidth = g_dw_cache_used_abs_width;
   flags |= g_dw_cache_flags;
   flags |= DW_FALLBACK_CACHE;
   return true;
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

void ReleaseDailyWindowCenterMAHandle()
{
   if(g_dw_center_ma_handle!=INVALID_HANDLE)
   {
      IndicatorRelease(g_dw_center_ma_handle);
      g_dw_center_ma_handle = INVALID_HANDLE;
   }
   g_dw_center_ma_period = 0;
}
void EnsureDailyWindowCenterMAHandle(int period)
{
   period = MathMax(0, period);
   if(period<=0)
   {
      ReleaseDailyWindowCenterMAHandle();
      return;
   }
   if(g_dw_center_ma_handle!=INVALID_HANDLE && g_dw_center_ma_period==period)
      return;

   ReleaseDailyWindowCenterMAHandle();
   ResetLastError();
   g_dw_center_ma_handle = iMA(_Symbol, PERIOD_D1, period, 0, MODE_SMA, PRICE_TYPICAL);
   g_dw_center_ma_period = (g_dw_center_ma_handle!=INVALID_HANDLE? period : 0);
   if(g_dw_center_ma_handle==INVALID_HANDLE && InpDebugLog)
   {
      int err = GetLastError();
      Dbg(StringFormat("[DW] falha ao criar iMA diário para o centro (p=%d err=%d)", period, err));
   }
}
bool TryGetDailyWindowCenterMA(double &value)
{
   value = 0.0;
   if(g_dw_center_ma_handle==INVALID_HANDLE)
      return false;

   int calc = BarsCalculated(g_dw_center_ma_handle);
   if(calc<=0)
      return false;

   double buf[];
   int copied = CopyBuffer(g_dw_center_ma_handle, 0, 0, 1, buf);
   if(copied<=0)
      return false;

   if(!MathIsValidNumber(buf[0]))
      return false;

   value = buf[0];
   return true;
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

int TrimRecentPivotSegments(Pivot &pivots[], int skip_segments)
{
   int count = ArraySize(pivots);
   if(count<=0) return 0;
   skip_segments = MathMax(0, skip_segments);
   if(skip_segments<=0) return count;

   int segments = MathMax(0, count-1);
   if(skip_segments >= segments){
      ArrayResize(pivots, 0);
      return 0;
   }

   int keep = count - skip_segments;
   if(keep < 2){
      ArrayResize(pivots, 0);
      return 0;
   }

   ArrayResize(pivots, keep);
   return keep;
}

void BuildLegsFromPivots(const Pivot &piv[],int piv_count,int legs_to_use, LegSeg &legs[],int &leg_count)
{
   ArrayResize(legs,0); leg_count=0;
   if(piv_count<2 || legs_to_use<=0) return;

   int start = piv_count-2;
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
string BuildPriceLabelBase(const FibItem &item)
{
   string text = RatioTag(item.ratio);
   text += (item.is_up? "+" : "-");
   if(InpLabelShowLeg) text += StringFormat(" L%d", item.leg_id);
   return text;
}
void BuildPriceLabelTexts(const FibItem &item, int clusterCount, string &left, string &right)
{
   left = BuildPriceLabelBase(item);
   if(InpPriceLabelTextMode == PRICE_LABEL_TEXT_TRADING){
      right = StringFormat("Lines:%d", clusterCount);
   }else{
      string clusterText = BuildClusterRightLabel(clusterCount);
      right = (StringLen(clusterText)>0 ? clusterText : left);
   }
}
string BuildPriceLabelIdentity(const FibItem &item)
{
   return StringFormat("L%d_R%.6f_E%d_U%d",
                       item.leg_id,
                       item.ratio,
                       (item.is_expansion? 1 : 0),
                       (item.is_up? 1 : 0));
}

void LabelSlotsBeginFrame()
{
   int need = ArraySize(g_label_slot_identity);
   if(ArraySize(g_label_slot_used) < need)
      ArrayResize(g_label_slot_used, need);
   for(int i=0;i<ArraySize(g_label_slot_used);i++)
      g_label_slot_used[i]=false;
}

int LabelSlotAcquire(const string &identity)
{
   for(int i=0;i<ArraySize(g_label_slot_identity);i++)
   {
      if(g_label_slot_identity[i]==identity)
      {
         if(i>=ArraySize(g_label_slot_used)){
            int newSize=i+1;
            ArrayResize(g_label_slot_used,newSize);
         }
         g_label_slot_used[i]=true;
         return i;
      }
   }
   for(int i=0;i<ArraySize(g_label_slot_identity);i++)
   {
      if(StringLen(g_label_slot_identity[i])==0)
      {
         g_label_slot_identity[i]=identity;
         if(i>=ArraySize(g_label_slot_used)){
            int newSize=i+1;
            ArrayResize(g_label_slot_used,newSize);
         }
         g_label_slot_used[i]=true;
         return i;
      }
   }
   int idx = ArraySize(g_label_slot_identity);
   ArrayResize(g_label_slot_identity, idx+1);
   ArrayResize(g_label_slot_used, idx+1);
   g_label_slot_identity[idx]=identity;
   g_label_slot_used[idx]=true;
   return idx;
}

void LabelSlotsEndFrame()
{
   long cid = ChartID();
   for(int i=0;i<ArraySize(g_label_slot_identity);i++)
   {
      bool used = (i<ArraySize(g_label_slot_used) ? g_label_slot_used[i] : false);
      if(!used && StringLen(g_label_slot_identity[i])>0)
      {
         string base = G_PREF_LBL + IntegerToString(i);
         ObjectDelete(cid, base + "_R");
         ObjectDelete(cid, base + "_L");
         g_label_slot_identity[i]="";
      }
   }
}

void ClearAllPriceLabels()
{
   long cid = ChartID();
   for(int i=0;i<ArraySize(g_label_slot_identity);i++){
      string base = G_PREF_LBL + IntegerToString(i);
      ObjectDelete(cid, base + "_R");
      ObjectDelete(cid, base + "_L");
      g_label_slot_identity[i]="";
      if(i<ArraySize(g_label_slot_used)) g_label_slot_used[i]=false;
   }
}

double LabelPriceTolerance(){ return MathMax(_Point*0.1, 1e-8); }
long LabelTimeTolerance(){ long tol=PeriodSeconds(); if(tol<=0) tol=60; return tol; }

bool ParseLabelMeta(const string &meta,string &identity,datetime &t,double &p,bool &manualLock)
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
string BuildLabelMeta(const string &identity,datetime t,double price,bool manualLock)
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

   double priceTol = LabelPriceTolerance();
   long timeTol = LabelTimeTolerance();

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

void MaintainPriceLabels(const FibItem &item,int slotIdx,const string &identBase,
                         double price,const string &textLeft,const string &textRight,color col,
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
   ManageSinglePriceLabel(nmRight, tRight, price, textRight, col, debugMode, ANCHOR_LEFT, identBase + "_R");
   if(InpLabelsMirrorLeft){
      ManageSinglePriceLabel(nmLeft, tLeft, price, textLeft, col, debugMode, ANCHOR_RIGHT, identBase + "_L");
   }else{
      ObjectDelete(cid, nmLeft);
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

bool BuildPricePipeline(const double &high[], const double &low[], const datetime &time[],
                        int rates_total, int pivot_lookback, int trim_segments, int legs_to_use,
                        Pivot &out_pivots[], int &out_pivot_count,
                        LegSeg &out_legs[], int &out_leg_count,
                        LineItem &out_price_lines[], int &out_price_count)
{
   const int clampTrim = MathMax(0, trim_segments);
   out_pivot_count = CollectPivots_ZZ(high, low, time, rates_total, pivot_lookback, out_pivots);
   out_pivot_count = TrimRecentPivotSegments(out_pivots, clampTrim);

   BuildLegsFromPivots(out_pivots, out_pivot_count, legs_to_use, out_legs, out_leg_count);
   BuildAllPriceLines(out_legs, out_leg_count, out_price_lines, out_price_count);

   bool havePivots = (out_pivot_count >= 2);
   bool haveLegs   = (out_leg_count   > 0);
   bool haveLines  = (out_price_count > 0);
   return (havePivots && haveLegs && haveLines);
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
                                      bool make_zones, double rect_thickness, bool force_zones,
                                      bool &member_all[],
                                      PRZ &zones[], int &zone_count)
{
   for(int i=0;i<ArraySize(member_all);i++) member_all[i]=false;
   ArrayResize(zones,0); zone_count=0;
   if(n<=0 || range<=0.0 || min_lines<=1) return;

   const double h = range*0.5;
   double tol = LabelPriceTolerance();
   if(tol<=0.0) tol = 1e-8;

   double bucketPrice[];
   int bucketStart[];
   int bucketLen[];
   ArrayResize(bucketPrice, n);
   ArrayResize(bucketStart, n);
   ArrayResize(bucketLen, n);

   int bucketCount=0;
   int idx=0;
   while(idx<n)
   {
      double base = P[idx];
      int start = idx;
      int len = 1;
      idx++;
      while(idx<n && MathAbs(P[idx]-base) <= tol){
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

   bool allowSmallZones = (force_zones && make_zones);

   for(int anchor=0; anchor<bucketCount; ++anchor)
   {
      double center = bucketPrice[anchor];
      double L = center - h;
      double R = center + h;
      int s = LowerBound(bucketPrice, bucketCount, L - tol);
      int e = UpperBound(bucketPrice, bucketCount, R + tol);
      int uniqueCnt = e - s;
      bool qualifies = (uniqueCnt >= min_lines);
      if(!qualifies && !allowSmallZones) continue;

      int totalCnt = 0;
      double clusterLow = P[bucketStart[s]];
      double clusterHigh = P[bucketStart[e-1] + bucketLen[e-1]-1];

      for(int bucket=s; bucket<e; ++bucket)
      {
         int startIdx = bucketStart[bucket];
         int len = bucketLen[bucket];
         totalCnt += len;
         if(qualifies){
            for(int k=0;k<len;k++){
               int all_idx = idx_sorted[startIdx + k];
               if(all_idx>=0 && all_idx<ArraySize(member_all)) member_all[all_idx]=true;
            }
         }
      }

      if(make_zones && (qualifies || force_zones)){
         int ci = ArraySize(cand)+1;
         ArrayResize(cand, ci);
         cand[ci-1].low = clusterLow;
         cand[ci-1].high = clusterHigh;
         cand[ci-1].center = 0.5*(clusterLow+clusterHigh);
         cand[ci-1].unique_cnt = uniqueCnt;
         cand[ci-1].total_cnt = totalCnt;
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
         int m=ArraySize(zones)+1; ArrayResize(zones,m); zones[m-1]=z;

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
      int m=ArraySize(zones)+1; ArrayResize(zones,m); zones[m-1]=z;
   }
   zone_count=ArraySize(zones);
}

int ClusterLineCountForPrice(double price)
{
   double tol = LabelPriceTolerance();
   for(int i=0;i<g_prz_count;i++){
      double low = g_prz[i].low - tol;
      double high = g_prz[i].high + tol;
      if(price >= low && price <= high)
         return g_prz[i].count;
   }
   return 0;
}

string BuildClusterRightLabel(int clusterCount)
{
   if(clusterCount<=0) return "";
   return StringFormat("%d linhas", clusterCount);
}

string BuildPRZLabelText(int lineCount)
{
   bool hasIntPlaceholder =
      (StringFind(InpPRZLabelFormat, "%d")>=0 || StringFind(InpPRZLabelFormat, "%i")>=0);
   if(StringLen(InpPRZLabelFormat)>0 && hasIntPlaceholder)
      return StringFormat(InpPRZLabelFormat, lineCount);
   if(StringLen(InpPRZLabelFormat)>0)
      return InpPRZLabelFormat + " (" + IntegerToString(lineCount) + ")";
   return StringFormat("PRZ (n=%d)", lineCount);
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
      double priceToDraw = all[i].price;
      UpsertPriceSegment(ln, segL, segR, priceToDraw, col, lineWidth);

      if(InpShowLabels){
         int clusterCount = ClusterLineCountForPrice(priceToDraw);
         string lblLeft, lblRight;
         BuildPriceLabelTexts(all[i], clusterCount, lblLeft, lblRight);
         string identBase = BuildPriceLabelIdentity(all[i]);
         int slotIdx = LabelSlotAcquire(identBase);
         MaintainPriceLabels(all[i], slotIdx, identBase, priceToDraw, lblLeft, lblRight, col, labelLeft, labelRight);
      }
      drawn++;
   }

   for(int i=drawn;i<g_prev_line_count;i++){
      ObjectDelete(ChartID(), G_PREF_LINE+IntegerToString(i));
   }
   g_prev_line_count = drawn;
   return drawn;
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
            string labelText = BuildPRZLabelText(zones[i].count);
            UpsertText(tn, tR, zones[i].high, labelText, InpPRZLabelColor, 8);
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
void SanitizePriceLineObjects()
{
   long cid = ChartID();
   int keep = MathMax(0, g_prev_line_count);
   int total = ObjectsTotal(cid, 0, -1);
   for(int i=total-1; i>=0; --i)
   {
      string name = ObjectName(cid, i, 0);
      if(StringFind(name, G_PREF_LINE)!=0)
         continue;
      int prefLen = StringLen(G_PREF_LINE);
      if(StringLen(name) <= prefLen)
         continue;
      string suffix = StringSubstr(name, prefLen);
      bool numeric=true;
      for(int c=0;c<StringLen(suffix);c++)
      {
         ushort ch = (ushort)StringGetCharacter(suffix, c);
         if(ch<'0' || ch>'9')
         {
            numeric=false;
            break;
         }
      }
      if(!numeric)
         continue;
      int idx = (int)StringToInteger(suffix);
      if(idx<0 || idx>=keep)
         ObjectDelete(cid, name);
   }
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
      double priceToDraw = source[i].price;
      UpsertPriceSegment(nm, segL, segR, priceToDraw, lineColor, MathMax(1, InpFibLineWidth), STYLE_DASHDOTDOT);
      string lbl = prefLabel + IntegerToString(drawn);
      string text = StringFormat("DBG %s (leg %d)", RatioTag(source[i].ratio), source[i].leg_id);
      UpsertText(lbl, tR, priceToDraw, text, lineColor, 8);
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
   EnsureDailyWindowCenterMAHandle(MathMax(0, G_DW_CENTER_MA_PERIOD));
   g_dw_cache_valid = false;

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
   ReleaseDailyWindowCenterMAHandle();
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

   if(g_prev_label_mode != InpPriceLabelMode){
      ClearAllPriceLabels();
      g_prev_label_mode = InpPriceLabelMode;
   }

   // 1) Pivôs & Pernas — conforme a FONTE escolhida
   const int primary_start_offset   = MathMax(0, InpZigZagPrimaryStartOffset);
   const int secondary_start_offset = MathMax(0, InpZigZagSecondaryStartOffset);

   Pivot piv[]; int pivot_count=0;
   LegSeg legs[]; int leg_count=0;
   LineItem price_lines[]; int price_count=0;
   bool price_pipeline_ready = BuildPricePipeline(high, low, time, rates_total,
                                                  InpPivotScanLookbackBars,
                                                  primary_start_offset,
                                                  InpLegsToUse,
                                                  piv, pivot_count,
                                                  legs, leg_count,
                                                  price_lines, price_count);

   DrawZigZagOverlay(g_zz_handle,
                     InpShowZigZagPrimary,
                     G_PREF_ZZ1, g_prev_zz1_count,
                     InpZigZagPrimaryColor, InpZigZagPrimaryWidth,
                     high, low, time, rates_total, InpPivotScanLookbackBars, primary_start_offset,
                     InpShowZigZagPrimary,
                     G_PREF_ZZ1_PIV, g_prev_zz1_piv_count,
                     InpZigZagPrimaryPivotColor, InpZigZagPrimaryPivotSize);
   DrawZigZagOverlay(g_zz2_handle,
                     InpShowZigZagSecondary,
                     G_PREF_ZZ2, g_prev_zz2_count,
                     InpZigZagSecondaryColor, InpZigZagSecondaryWidth,
                     high, low, time, rates_total, InpPivotScanLookbackBars, secondary_start_offset,
                     InpShowZigZagSecondary,
                     G_PREF_ZZ2_PIV, g_prev_zz2_piv_count,
                     InpZigZagSecondaryPivotColor, InpZigZagSecondaryPivotSize);

   if(!price_pipeline_ready)
      return rates_total;

   CapturePivotStats(piv, pivot_count);
   g_leg_total = leg_count;
   DrawLegs(legs, leg_count);

   ArrayResize(g_price_all, price_count);
   ArrayCopy(g_price_all, price_lines);
   g_price_total = price_count;

   // 2) Linhas PREÇO + TEMPO
   if(InpShowTimeFibs){ BuildTimeMarks(legs, leg_count, g_time_all, g_time_total); }
   else{ ArrayResize(g_time_all,0); g_time_total=0; }

   // 3) Base única + views
   BuildUnifiedFromLegacy(g_price_all, g_price_total,
                          g_time_all,  g_time_total,
                          g_all, g_all_total,
                          g_view_price, g_view_time);

   bool needDailyWindow = (InpUseDailyWindow || G_DW_SHOW_INFO);
   double dwLow=0.0, dwHigh=0.0, dwMid=0.0, dwAtr=0.0;
   datetime dwTStart=0, dwTEnd=0;
   int dwFlags = DW_FALLBACK_NONE;
   bool dwCenterMA=false;
   bool dwUsedAbsHeight=false, dwUsedAbsWidth=false;
   bool dwOk=false;
   if(needDailyWindow){
      dwOk = GetDailyWindowBounds(time, high, low, rates_total,
                                  dwLow, dwHigh, dwMid, dwAtr, dwFlags,
                                  dwTStart, dwTEnd, dwCenterMA,
                                  dwUsedAbsHeight, dwUsedAbsWidth);
      if(dwOk){
         StoreDailyWindowCache(dwLow, dwHigh, dwMid, dwAtr,
                               dwTStart, dwTEnd,
                               dwCenterMA, dwUsedAbsHeight, dwUsedAbsWidth,
                               dwFlags);
      }else if(TryRestoreDailyWindowCache(dwLow, dwHigh, dwMid, dwAtr,
                                          dwTStart, dwTEnd,
                                          dwCenterMA, dwUsedAbsHeight, dwUsedAbsWidth,
                                          dwFlags))
      {
         dwOk = true;
      }
   }else{
      g_dw_cache_valid = false;
   }
   g_dw_active = (dwOk && InpUseDailyWindow);
   g_dw_time_left  = (g_dw_active? dwTStart : 0);
   g_dw_time_right = (g_dw_active? dwTEnd   : 0);
   double dwSpan = (dwOk? dwHigh-dwLow : 0.0);
   if(InpUseDailyWindow && dwOk){
      int backup[];
      ArrayCopy(backup, g_view_price);
      ApplyDailyWindowFilter(g_all, g_view_price, dwLow, dwHigh);
      if(ArraySize(g_view_price)==0){
         ArrayCopy(g_view_price, backup);
         dwFlags |= DW_FALLBACK_EMPTY;
      }
   }
   ShowDailyWindowFallbackNotice(needDailyWindow? dwFlags : DW_FALLBACK_NONE);
   ShowDailyWindowInfo(G_DW_SHOW_INFO, dwOk, dwLow, dwHigh, dwMid, dwAtr, dwFlags, dwSpan, dwCenterMA,
                       dwUsedAbsHeight, dwUsedAbsWidth);
   DrawDailyWindowBounds(G_DW_SHOW_BOUNDS, G_DW_SHOW_CENTER_LINE,
                         dwOk && needDailyWindow,
                         dwLow, dwHigh, dwMid,
                         dwTStart, dwTEnd,
                         time, rates_total);

   CountPriceSubtypes(g_all, g_all_total);

   // 4) PREÇO — modo
   LabelSlotsBeginFrame();
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
         if(i<0 || i>=g_all_total) continue;
         color col=(g_all[i].is_expansion ? InpExpandLineColor : InpRetraceLineColor);
         string ln=G_PREF_LINE+IntegerToString(drawn);
         double priceToDraw = g_all[i].price;
         UpsertPriceSegment(ln, segL, segR, priceToDraw, col, lineWidth);
         if(InpShowLabels){
            int clusterCount = ClusterLineCountForPrice(priceToDraw);
            string lblLeft, lblRight;
            BuildPriceLabelTexts(g_all[i], clusterCount, lblLeft, lblRight);
            string identBase = BuildPriceLabelIdentity(g_all[i]);
            int slotIdx = LabelSlotAcquire(identBase);
            MaintainPriceLabels(g_all[i], slotIdx, identBase, priceToDraw, lblLeft, lblRight, col, labelLeft, labelRight);
         }
         drawn++;
      }
      for(int i=drawn;i<g_prev_line_count;i++){
         ObjectDelete(ChartID(), G_PREF_LINE+IntegerToString(i));
      }
      g_prev_line_count=drawn;

      ClearPRZObjects();
      ClearShadowClusterRects();
      ArrayResize(g_prz_shadow_flag,0);
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
                                      InpDrawPRZRectangles, rect_thick, InpPRZForceShow,
                                      member_all, g_prz, g_prz_count);
     for(int k=0;k<n;k++){
        int idx = g_view_price[k];
        if(idx<0 || idx>=ArraySize(member_all)) continue;
        if(!member_all[idx]) continue;
     }

     EvaluateShadowClusters(time, open, high, low, close, tick_volume, rates_total);
     g_visible_cluster_lines = DrawClusterLines(g_all, g_view_price, n, member_all, time, rates_total);
     DrawPRZZones(g_prz, g_prz_count, time, rates_total);
     DrawShadowClusterRects(time, rates_total);

     if(InpDebugLog){
     Dbg(StringFormat("[Fibo][%s] Src=ZZ  ATR(1D,p=%d)=%.5f  Range=%.2f%%  MinLines=%d  PRZ=%d  ClusterLines=%d  LinesTot=%d",
           _Symbol,
            InpATR_D1_Periods, atrD1, InpClusterRangePctATR, InpClusterMinLines,
            g_prz_count, g_visible_cluster_lines, n));
     }
   }
   SanitizePriceLineObjects();
   LabelSlotsEndFrame();

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
      string ln2 = StringFormat("PRICE  R:%d  X:%d  MinLinhas:%d  Pernas:%d  Topos:%d  Fundos:%d",
                                g_R_all, g_X_all, InpClusterMinLines, g_leg_total, g_pivot_tops, g_pivot_bottoms);
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
