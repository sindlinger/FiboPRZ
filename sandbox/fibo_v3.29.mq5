#property copyright "2025"
#property link      ""
#property version   "3.25"
#property strict
#property indicator_chart_window
#property indicator_plots 0

// ========================= Inputs =========================

// --- Fonte dos pivôs: ZigZag OU L/R/Strict (restaurado)
enum ENUM_PIVOT_SOURCE { PIV_ZIGZAG=0, PIV_LR=1 };
input ENUM_PIVOT_SOURCE InpPivotSource    = PIV_ZIGZAG;

// --- ZigZag (pivôs por iCustom)
input int      InpZZ_Depth               = 12;    // ZigZag: Depth
input int      InpZZ_Deviation           = 5;     // ZigZag: Deviation
input int      InpZZ_Backstep            = 3;     // ZigZag: Backstep

// --- Pivôs proeminentes (L/R/Strict) — RESTAURADOS
input int      InpPivotLeftBars          = 26;    // barras à ESQUERDA p/ validar pivô
input int      InpPivotRightBars         = 26;    // barras à DIREITA  p/ validar pivô
input bool     InpPivotStrict            = true;  // estrito? (> e <) senão permite >= e <=
input int      InpPivotScanLookbackBars  = 500;   // quantas barras recentes escanear

// --- Desempate/precedência quando ambíguo (“preeminência do topo”)
input bool     InpPreferHighWhenAmbiguous = true; // empate → favorece topo?

// --- Margem à direita p/ rótulos (em barras)
input int      InpRightTextMarginBars    = 6;

// --- Pernas (linhas A->B)
input int      InpLegsToUse              = 15;      // quantas pernas usar
input bool     InpShowLegs               = true;   // desenhar pernas (visual)
input color    InpLegUpColor             = clrLime;
input color    InpLegDnColor             = clrOrange;
input int      InpLegWidth               = 1;

// --- Projeções por perna (4 preço + 2 tempo)
input bool     InpEnableRetUp            = true;   // preço: retração acima de B (R↑)
input bool     InpEnableRetDown          = true;   // preço: retração abaixo de B (R↓)
input bool     InpEnableExpUp            = true;   // preço: expansão acima de B (X↑)
input bool     InpEnableExpDown          = true;   // preço: expansão abaixo de B (X↓)
input bool     InpTimeBothDirections     = true;   // tempo: adiante e atrás
input bool     InpTimeAllLegs            = false;  // tempo: todas as pernas? (false = só base)
input int      InpTimeBaseLeg            = 2;      // tempo: perna base (0 = mais recente)
input int      InpTimeMarkersPerLeg      = 3;      // tempo: quantas razões (máx)

// --- Razões (misture retrações <=1 e expansões >1)
input string   InpFibRatios              = "0.236,0.618,1.0,1.272,1.618,2.0,2.618,3.618,4.236";
input string   InpTimeFibRatios          = "0.618,1.0,1.618,2.618,4.236";

// --- ATR diário (1D) e cluster (sem pips!)
input int      InpATR_D1_Periods         = 14;     // ATR(1D) período (média de x dias)
input double   InpClusterRangePctATR     = 10.0;   // ESPESSURA do cluster = % do ATR(1D)
input int      InpClusterMinLines        = 7;      // mínimo de linhas para existir cluster

// --- Modo de exibição de PREÇO
enum ENUM_PRICE_MODE { PRICE_CLUSTER=0, PRICE_RAW=1 };
input ENUM_PRICE_MODE InpPriceMode       = PRICE_CLUSTER; // padrão = LINHAS em CLUSTER

// --- Aparência das linhas de preço
input int      InpFibLineWidth           = 1;
input color    InpRetraceLineColor       = clrDeepSkyBlue; // R
input color    InpExpandLineColor        = clrOrangeRed;   // X
input bool     InpShowLabels             = true;           // rótulos (ratio) nas linhas

// --- Overlay de debug (todas as linhas, pontilhado)
input bool     InpDebugOverlayAllPriceLines = false;

// --- TEMPO (bolinhas e vlines)
input bool     InpShowTimeFibs           = false;        // liga/desliga marcas de tempo
input bool     InpShowTimeVLines         = true;         // além do ponto, desenhar VLINE
input color    InpTimeDotColor           = clrSilver;
input int      InpTimeDotFontSize        = 8;

// --- PRZ como retângulos (opcional, OFF por padrão)
input bool     InpDrawPRZRectangles      = false;     // OFF = padrão (apenas linhas-cluster)
input bool     InpPRZRectUseCustomPctATR = false;     // ON = usar espessura custom abaixo
input double   InpPRZRectThicknessPctATR = 5.0;      // espessura do retângulo (% do ATR 1D) quando custom ON
input color    InpPRZRectColor           = clrAliceBlue;
input int      InpPRZRectBorderWidth     = 1;

// --- Resumo/Debug visual
input bool     InpShowSummary            = true;
input bool     InpSummaryShowBreakdown   = true;
input int      InpSummaryFontSize        = 14;
input bool     InpDebugLog               = false;
input int      InpDebugPrintLimit        = 200;

// ========================= Tipos =========================
struct Pivot { double price; datetime time; bool is_high; int index; };
struct LegSeg { double p1,p2; datetime t1,t2; bool is_up; int id; };

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

int             g_prev_line_count = 0;
int             g_prev_leg_count  = 0;
int             g_prev_tf_count   = 0;
int             g_prev_tfvl_count = 0;
int             g_prev_raw_count  = 0;
int             g_prev_prz_count  = 0;

int             g_dbg_prints = 0;

// bases e views
LineItem        g_price_all[];   int g_price_total = 0;
TimeItem        g_time_all[];    int g_time_total  = 0;

FibItem         g_all[];         int g_all_total   = 0;
int             g_view_price[];
int             g_view_time[];

// PRZs
PRZ             g_prz[];
int             g_prz_count = 0;

// contadores
int             g_R_all=0, g_X_all=0;
int             g_visible_cluster_lines = 0;

// ZigZag handle
int             g_zz_handle = INVALID_HANDLE;

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

void UpsertHLine(const string &name,double price,color col,int w)
{
   long cid=ChartID();
   if(ObjectFind(cid,name)<0) ObjectCreate(cid,name,OBJ_HLINE,0,0,price);
   ObjectSetDouble (cid,name,OBJPROP_PRICE,price);
   ObjectSetInteger(cid,name,OBJPROP_COLOR,col);
   ObjectSetInteger(cid,name,OBJPROP_WIDTH,w);
   ObjectSetInteger(cid,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(cid,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(cid,name,OBJPROP_BACK,false);
}
void UpsertHLineStyled(const string &name,double price,color col,int w,ENUM_LINE_STYLE style)
{
   long cid=ChartID();
   if(ObjectFind(cid,name)<0) ObjectCreate(cid,name,OBJ_HLINE,0,0,price);
   ObjectSetDouble (cid,name,OBJPROP_PRICE,price);
   ObjectSetInteger(cid,name,OBJPROP_COLOR,col);
   ObjectSetInteger(cid,name,OBJPROP_WIDTH,w);
   ObjectSetInteger(cid,name,OBJPROP_STYLE,style);
   ObjectSetInteger(cid,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(cid,name,OBJPROP_BACK,false);
}
void UpsertText(const string &name,datetime t,double price,const string &text,color col,int fontsize=8)
{
   long cid=ChartID();
   if(ObjectFind(cid,name)<0) ObjectCreate(cid,name,OBJ_TEXT,0,t,price);
   else ObjectMove(cid,name,0,t,price);
   ObjectSetString (cid,name,OBJPROP_TEXT,text);
   ObjectSetInteger(cid,name,OBJPROP_COLOR,col);
   ObjectSetInteger(cid,name,OBJPROP_FONTSIZE,fontsize);
   ObjectSetInteger(cid,name,OBJPROP_ANCHOR,ANCHOR_LEFT);
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

// ========================= Pivôs (duas fontes) =========================
bool IsPivotHigh(const double &high[],int i,int total,int L,int R,bool strict)
{
   if(i-L < 0 || i+R >= total) return false;
   for(int k=1;k<=L;k++){ int li=i-k; if(strict? high[i]<=high[li] : high[i]<high[li]) return false; }
   for(int k=1;k<=R;k++){ int ri=i+k; if(strict? high[i]<=high[ri] : high[i]<high[ri]) return false; }
   return true;
}
bool IsPivotLow(const double &low[],int i,int total,int L,int R,bool strict)
{
   if(i-L < 0 || i+R >= total) return false;
   for(int k=1;k<=L;k++){ int li=i-k; if(strict? low[i]>=low[li] : low[i]>low[li]) return false; }
   for(int k=1;k<=R;k++){ int ri=i+k; if(strict? low[i]>=low[ri] : low[i]>low[ri]) return false; }
   return true;
}

int CollectPivots_LR(const double &high[],const double &low[],const datetime &time[],
                     int total,int lookback,int L,int R,bool strict,
                     Pivot &pivots[])
{
   ArrayResize(pivots,0);
   if(total<=0) return 0;

   bool series=IsSeries(time,total);
   int use=MathMin(lookback,total);
   int from= series? 0 : total-use;
   int to  = series? use-1 : total-1;

   int start = MathMax(from, L);
   int end   = MathMin(to,   total-1-R);
   if(end < start) return 0;

   for(int i=start;i<=end;i++)
   {
      bool ph = IsPivotHigh(high,i,total,L,R,strict);
      bool pl = IsPivotLow (low ,i,total,L,R,strict);

      // se ambos verdadeiros (ambiguidade), aplica preeminência configurável
      if(ph && pl){
         if(InpPreferHighWhenAmbiguous){
            int n=ArraySize(pivots)+1; ArrayResize(pivots,n);
            pivots[n-1].price=high[i]; pivots[n-1].time=time[i]; pivots[n-1].is_high=true; pivots[n-1].index=i;
         }else{
            int n=ArraySize(pivots)+1; ArrayResize(pivots,n);
            pivots[n-1].price=low[i];  pivots[n-1].time=time[i]; pivots[n-1].is_high=false; pivots[n-1].index=i;
         }
      }else if(ph){
         int n=ArraySize(pivots)+1; ArrayResize(pivots,n);
         pivots[n-1].price=high[i]; pivots[n-1].time=time[i]; pivots[n-1].is_high=true;  pivots[n-1].index=i;
      }else if(pl){
         int n=ArraySize(pivots)+1; ArrayResize(pivots,n);
         pivots[n-1].price=low[i];  pivots[n-1].time=time[i];  pivots[n-1].is_high=false; pivots[n-1].index=i;
      }
   }

   // ordenar por tempo crescente
   int N=ArraySize(pivots);
   for(int a=0;a<N-1;a++){
      int best=a;
      for(int b=a+1;b<N;b++) if(pivots[b].time<pivots[best].time) best=b;
      if(best!=a){ Pivot t=pivots[a]; pivots[a]=pivots[best]; pivots[best]=t; }
   }
   return ArraySize(pivots);
}

int CollectPivots_ZZ(const double &high[],const double &low[],const datetime &time[],
                     int total,int lookback,
                     Pivot &pivots[])
{
   ArrayResize(pivots,0);
   if(total<=0 || g_zz_handle==INVALID_HANDLE) return 0;

   int use = MathMin(lookback, total);
   bool series = IsSeries(time, total);
   int from = series? 0 : total - use;
   int to   = series? use-1 : total-1;
   if(from<0) from=0; if(to<0) return 0;

   static double zz[], hi[], lo[];
   int c0 = CopyBuffer(g_zz_handle, 0, 0, total, zz);
   int c1 = CopyBuffer(g_zz_handle, 1, 0, total, hi);
   int c2 = CopyBuffer(g_zz_handle, 2, 0, total, lo);
   if(c0<=0) return 0;

   for(int i=from; i<=to; ++i)
   {
      bool hasZZ = (i<c0 && zz[i]!=0.0);
      bool isHigh = (i<c1 && hi[i]!=0.0);
      bool isLow  = (i<c2 && lo[i]!=0.0);
      if(!hasZZ && !isHigh && !isLow) continue;

      double price = 0.0; bool ph=false;
      if(isHigh){ price = hi[i]; ph=true; }
      else if(isLow){ price = lo[i]; ph=false; }
      else{
         price = zz[i];
         double dh = MathAbs(price - high[i]);
         double dl = MathAbs(price - low[i]);
         ph = (dh==dl ? InpPreferHighWhenAmbiguous : (dh < dl));
      }

      int n=ArraySize(pivots)+1; ArrayResize(pivots,n);
      pivots[n-1].price   = price;
      pivots[n-1].time    = time[i];
      pivots[n-1].is_high = ph;
      pivots[n-1].index   = i;
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

void BuildLegsFromPivots(const Pivot &piv[],int piv_count,int legs_to_use, LegSeg &legs[],int &leg_count)
{
   ArrayResize(legs,0); leg_count=0;
   if(piv_count<2 || legs_to_use<=0) return;

   int built=0;
   for(int i=piv_count-2; i>=0 && built<legs_to_use; --i)
   {
      LegSeg Lg;
      Lg.t1=piv[i].time;   Lg.p1=piv[i].price;
      Lg.t2=piv[i+1].time; Lg.p2=piv[i+1].price;

      // Garante A mais antigo e B avançado
      if(Lg.t2 < Lg.t1){
         datetime t=Lg.t1; Lg.t1=Lg.t2; Lg.t2=t;
         double   p=Lg.p1; Lg.p1=Lg.p2; Lg.p2=p;
      }
      Lg.is_up=(Lg.p2>Lg.p1);
      Lg.id=built;
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

// ========================= Linhas de PREÇO (geração) =================
string RatioTag(double ratio){ double pct=ratio*100.0; bool is_exp=(pct>100.0); return StringFormat("%s%.1f",(is_exp? "X":"R"),pct); }

void BuildAllPriceLines(const LegSeg &legs[],int leg_count,
                        LineItem &out[],int &out_count)
{
   ArrayResize(out,0); out_count=0;
   if(leg_count<=0 || ArraySize(g_fib_ratios)==0) return;

   for(int i=0;i<leg_count;i++)
   {
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
      long dt = (long)MathAbs((long)legs[L].t2 - (long)legs[L].t1);
      if(dt<=0) continue;

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
      int idxr=series?0:total-1;
      int ps=PeriodSeconds(); if(ps<=0) ps=60;
      tR=(datetime)((long)time[idxr] + ps*InpRightTextMarginBars);
   }

   for(int k=0;k<n;k++){
      int i=view_idx[k];
      if(i<0 || i>=ArraySize(member_all)) continue;
      if(!member_all[i]) continue;

      color col = (all[i].is_expansion ? InpExpandLineColor : InpRetraceLineColor);
      string ln = G_PREF_LINE+IntegerToString(drawn);
      UpsertHLine(ln, all[i].price, col, InpFibLineWidth);

      if(InpShowLabels){
         string lbl = RatioTag(all[i].ratio);
         string tn  = G_PREF_LBL+IntegerToString(drawn);
         UpsertText(tn, tR, all[i].price, lbl, col, 8);
      }
      drawn++;
   }

   for(int i=drawn;i<g_prev_line_count;i++){
      ObjectDelete(ChartID(), G_PREF_LINE+IntegerToString(i));
      ObjectDelete(ChartID(), G_PREF_LBL +IntegerToString(i));
   }
   g_prev_line_count = drawn;
   return drawn;
}
void DrawPriceOverlayAll(const FibItem &all[], const int &view_idx[], int n, bool enabled)
{
   int drawn=0;
   if(enabled){
      for(int k=0;k<n;k++){
         int i=view_idx[k];
         string nm = G_PREF_RAW + IntegerToString(drawn++);
         UpsertHLineStyled(nm, all[i].price, clrSilver, 1, STYLE_DOT);
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

// ========================= Contadores =========================
bool MatchesPct(double ratio, double pct){ return MathAbs(ratio*100.0 - pct) <= 0.15; }
void CountPriceSubtypes(const FibItem &all[], int allN){ g_R_all=g_X_all=0; for(int i=0;i<allN;i++){ if(all[i].kind!=FIBK_PRICE) continue; if(all[i].is_expansion) g_X_all++; else g_R_all++; } }

// ========================= Lifecycle =========================
int OnInit()
{
   if(!ParseRatiosTo(InpFibRatios, g_fib_ratios)){ Print("Fibo: não foi possível interpretar as razões de PREÇO."); return INIT_FAILED; }
   ParseRatiosTo(InpTimeFibRatios, g_time_ratios);
   ClearByPrefix("FCZ");

   // cria handle do ZigZag (permite trocar a fonte on-the-fly via inputs)
   g_zz_handle = iCustom(_Symbol, _Period, "ZigZag", InpZZ_Depth, InpZZ_Deviation, InpZZ_Backstep);
   if(g_zz_handle==INVALID_HANDLE && InpPivotSource==PIV_ZIGZAG){
      Print("Falha ao criar ZigZag via iCustom. Verifique se o indicador padrão 'ZigZag' está disponível.");
      return INIT_FAILED;
   }
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason){
   ClearByPrefix("FCZ");
   if(g_zz_handle!=INVALID_HANDLE) IndicatorRelease(g_zz_handle);
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
   Pivot piv[]; int pc=0;
   if(InpPivotSource==PIV_ZIGZAG) pc = CollectPivots_ZZ(high,low,time,rates_total, InpPivotScanLookbackBars, piv);
   else                           pc = CollectPivots_LR(high,low,time,rates_total, InpPivotScanLookbackBars, InpPivotLeftBars, InpPivotRightBars, InpPivotStrict, piv);

   LegSeg legs[]; int leg_count=0;
   BuildLegsFromPivots(piv, pc, InpLegsToUse, legs, leg_count);
   DrawLegs(legs,leg_count);

   // 2) Linhas PREÇO + TEMPO
   BuildAllPriceLines(legs,leg_count, g_price_all, g_price_total);
   if(InpShowTimeFibs){ BuildTimeMarks(legs, leg_count, g_time_all, g_time_total); }
   else{ ArrayResize(g_time_all,0); g_time_total=0; }

   // 3) Base única + views
   BuildUnifiedFromLegacy(g_price_all, g_price_total,
                          g_time_all,  g_time_total,
                          g_all, g_all_total,
                          g_view_price, g_view_time);
   CountPriceSubtypes(g_all, g_all_total);

   // 4) PREÇO — modo
   if(InpPriceMode==PRICE_RAW)
   {
      int drawn=0;
      datetime tL=0,tR=0; double pmin=0,pmax=0;
      if(!GetVisibleWindow(time,rates_total,tL,tR,pmin,pmax)){
         bool series=IsSeries(time,rates_total);
         int idx=series?0:rates_total-1;
         int ps=PeriodSeconds(); if(ps<=0) ps=60;
         tR=(datetime)((long)time[idx] + ps*InpRightTextMarginBars);
      }

      for(int k=0;k<ArraySize(g_view_price);k++){
         int i=g_view_price[k];
         color col=(g_all[i].is_expansion ? InpExpandLineColor : InpRetraceLineColor);
         string ln=G_PREF_LINE+IntegerToString(drawn);
         UpsertHLine(ln, g_all[i].price, col, InpFibLineWidth);
         if(InpShowLabels){
            string lbl=RatioTag(g_all[i].ratio);
            string tn =G_PREF_LBL+IntegerToString(drawn);
            UpsertText(tn, tR, g_all[i].price, lbl, col, 8);
         }
         drawn++;
      }
      for(int i=drawn;i<g_prev_line_count;i++){
         ObjectDelete(ChartID(), G_PREF_LINE+IntegerToString(i));
         ObjectDelete(ChartID(), G_PREF_LBL +IntegerToString(i));
      }
      g_prev_line_count=drawn;

      ClearPRZObjects();
      DrawPriceOverlayAll(g_all, g_view_price, ArraySize(g_view_price), false);
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

     g_visible_cluster_lines = DrawClusterLines(g_all, g_view_price, n, member_all, time, rates_total);
     DrawPRZZones(g_prz, g_prz_count, time, rates_total);
     DrawPriceOverlayAll(g_all, g_view_price, n, InpDebugOverlayAllPriceLines);

     if(InpDebugLog){
       Dbg(StringFormat("[Fibo][%s] Src=%s  ATR(1D,p=%d)=%.5f  Range=%.2f%%  MinLines=%d  PRZ=%d  ClusterLines=%d  LinesTot=%d",
            _Symbol, (InpPivotSource==PIV_ZIGZAG? "ZZ":"LR"),
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

   // 6) RESUMO (visor)
   if(InpShowSummary)
   {
      string ln1 = StringFormat(
         "PRICE  Linhas:%d  EmCluster:%d  PRZs:%d  Range=%.2f%% ATR(1D,p=%d)",
         ArraySize(g_view_price), g_visible_cluster_lines, g_prz_count, InpClusterRangePctATR, InpATR_D1_Periods
      );
      string ln2 = StringFormat("PRICE  R:%d  X:%d  MinLinhas:%d", g_R_all, g_X_all, InpClusterMinLines);
      string ln3 = StringFormat(
         "TIME   Marcas:%d  VLines:%s  (ambas direções=%s  base=%s)   Pivots=%s",
         ArraySize(g_view_time), (InpShowTimeVLines? "sim":"não"),
         (InpTimeBothDirections? "sim":"não"), (InpTimeAllLegs? "todas":"base"),
         (InpPivotSource==PIV_ZIGZAG? "ZigZag":"L/R")
      );

      string text = (InpSummaryShowBreakdown ? (ln1+"\n"+ln2+"\n"+ln3) : (ln1+"\n"+ln3));
      ShowSummaryLabel(text);
   }else{
      ClearSummaryLabel();
   }

   return rates_total;
}
