//+------------------------------------------------------------------+
//|                                           PRZ_Adensamento.mq5    |
//| Pivôs P1/P2, ATR D1, Histerese, PRZ por Adensamento (Top-K)      |
//| Modo normal: só PRZ | Modo bug: todas as linhas e pernas         |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_plots 0
#property strict

//=============================
// 0) ESTRUTURAS E UTILITÁRIOS
//=============================
struct Pivot
{
   int      type;    // +1 topo, -1 fundo
   double   price;
   int      index;   // índice cronológico (0 = mais antigo)
   datetime time;
};

struct LineItem
{
   string id;        // id estável (pivotIndex_tipo_TAG_idx)
   double level;     // preço do nível
   int    depth;     // 1=P1, 2=P2
};

struct CandItem
{
   string id;
   double level;
   bool   on;
   int    depth;   // 1=P1, 2=P2 (para colorir linhas)
};

// --- trim simples (sem depender de StringTrim*)
bool is_space(int ch){ return(ch==32 || ch==9); } // ' ' ou '\t'
string TrimStr(string s)
{
   int len = StringLen(s);
   if(len==0) return s;
   int i=0, j=len-1;
   while(i<len && is_space(StringGetCharacter(s,i))) i++;
   while(j>=i   && is_space(StringGetCharacter(s,j))) j--;
   if(j<i) return "";
   return StringSubstr(s,i,j-i+1);
}

int FindCandById(CandItem &arr[], const string &id)
{
   int n = ArraySize(arr);
   for(int i=0;i<n;i++)
      if(arr[i].id==id) return i;
   return -1;
}

// --- parse de lista "0.382,0.5,0.618"
void ParseFloatList(string src, double &out[])
{
   ArrayResize(out,0);
   src = TrimStr(src);
   if(StringLen(src)==0) return;

   string parts[];
   // ATENÇÃO: separador é caractere (ushort), use vírgula entre aspas simples:
   int n = StringSplit(src, ',', parts);

   for(int i=0;i<n;i++)
   {
      string t = TrimStr(parts[i]);
      if(StringLen(t)==0) continue;
      double v = StringToDouble(t);
      if(MathIsValidNumber(v))
      {
         int k = ArraySize(out);
         ArrayResize(out,k+1);
         out[k] = v;
      }
   }
}


bool IsPivotTop(const double &hi[], int i, int k)
{
   double m = hi[i];
   for(int j=i-k;j<=i+k;j++) if(hi[j]>m) return false;
   return true;
}
bool IsPivotBottom(const double &lo[], int i, int k)
{
   double m = lo[i];
   for(int j=i-k;j<=i+k;j++) if(lo[j]<m) return false;
   return true;
}

// Alternância com substituição do extremo
void AppendPivotWithAlternation(Pivot &seq[], const Pivot &cand)
{
   int sz = ArraySize(seq);
   if(sz==0)
   {
      ArrayResize(seq,1);
      seq[0] = cand;
      return;
   }
   Pivot last = seq[sz-1];
   if(cand.type==last.type)
   {
      bool replace = (cand.type==1 ? (cand.price>last.price) : (cand.price<last.price));
      if(replace) seq[sz-1]=cand; // substitui pelo mais extremo
   }
   else
   {
      ArrayResize(seq,sz+1);
      seq[sz]=cand;
   }
}

int CountInRange(const double &levels[], double L, double U)
{
   int c=0, n=ArraySize(levels);
   for(int i=0;i<n;i++)
      if(levels[i]>=L && levels[i]<=U) c++;
   return c;
}

double Overlap(double a1,double a2,double b1,double b2)
{
   double left=MathMax(a1,b1), right=MathMin(a2,b2);
   double w = right-left;
   return (w>0.0 ? w : 0.0);
}

// Two-pointers: levels ORDENADO (asc), acha [L*,U*] com largura <=W e maior contagem
void BestDensity(const double &levels[], double W, double &Lbest, double &Ubest, int &Cbest, int &iLbest, int &iUbest)
{
   int n = ArraySize(levels);
   Lbest=EMPTY_VALUE; Ubest=EMPTY_VALUE; Cbest=0; iLbest=-1; iUbest=-1;
   if(n==0) return;
   int esq=0;
   for(int dir=0; dir<n; dir++)
   {
      while(esq<=dir && (levels[dir]-levels[esq]>W)) esq++;
      int count = dir-esq+1;
      if(count>Cbest)
      {
         Cbest = count;
         Lbest = levels[esq];
         Ubest = levels[dir];
         iLbest = esq; iUbest = dir;
      }
   }
}

// Remove elementos de tmp que estão dentro [L,U]
void RemoveRange(double &tmp[], double L,double U)
{
   double newarr[];
   int n=ArraySize(tmp);
   for(int i=0;i<n;i++)
   {
      double y = tmp[i];
      if(!(y>=L && y<=U))
      {
         int k=ArraySize(newarr);
         ArrayResize(newarr,k+1);
         newarr[k]=y;
      }
   }
   int m = ArraySize(newarr);
   ArrayResize(tmp,m);
   for(int i=0;i<m;i++) tmp[i]=newarr[i];
}

//=============================
// 1) PARÂMETROS DO USUÁRIO
//=============================
input int    P1_k = 14;
input int    P2_k = 52;
input int    N_P1 = 12;
input int    N_P2 = 10;

// Defaults preenchidos para funcionar "out of the box"
input string Retracoes = "0.236,0.382,0.5,0.618";  // retrações
input string Expansoes = "1.272,1.414,1.618";      // expansões
input string ProjTempo = "";                        // opcional: "0.618,1,1.618"

input int    ATR_Period_D1 = 14;
input double JanelaPctATR = 1.0;                // J_in = %ATR(D1)
input double HistereseExtraPctATR = 0.3;        // J_out = J_in + extra
input double LarguraPRZ_PctATR = 0.8;           // W = %ATR(D1)

input int    Nmin_PRZ = 5;
input int    TopK_PRZ = 1;
input int    DeltaCont = 1;
input double Tau_OverlapFrac = 0.5;

input bool   ShowWindow = true;
input int    WindowBars = 200;
input bool   ShowRules  = true;

// Exibição de linhas no modo normal
input bool   ShowLines   = true;
input int    MaxLines    = 250;

input bool   BugMode     = false;
input int    BugMaxLines = 250;
input int    BugMaxLegs  = 200;

input color  ColorP1    = clrAqua;
input color  ColorP2    = clrOrange;
input color  ColorPRZ   = clrMagenta;
input color  ColorWindow= clrGray;
input color  ColorTempo = clrYellow;
// ---- UI (texto das regras na tela, com fonte grande)
input bool   RulesAsLabel      = true;            // mostrar texto como label (em vez de Comment)
input bool   RulesUseRectLabel = true;            // usar OBJ_RECTANGLE_LABEL para multilinha e largura fixa
input int    RulesWidthPx      = 640;             // largura do painel (pixels)
input int    RulesHeightPx     = 0;               // altura do painel (px); 0 = auto
input bool   RulesAutoHeight   = true;            // calcula altura automaticamente pelo nº de linhas
input double RulesLineSpacing  = 1.35;            // fator de altura de linha (px ~ size*1.35)
input int    RulesPadY         = 8;               // padding vertical extra (px)
input color  RulesBgColor      = clrBlack;        // cor de fundo do painel
input bool   RulesBgTransparent= false;           // fundo sólido (mais visível por padrão)
input string RulesFontName     = "Lucida Console";// fonte monoespaçada parecida com arcade (segura)
input int    RulesFontSize     = 18;              // tamanho maior
input color  RulesTextColor    = clrWhite;        // cor do texto
input bool   RulesShadow       = true;            // desenha sombra para legibilidade
input int    RulesX            = 8;               // deslocamento X (px) a partir do canto
input int    RulesY            = 8;               // deslocamento Y (px)

//=============================
// 2) VARIÁVEIS GLOBAIS
//=============================
int      hATR = INVALID_HANDLE;
double   prevMainL = EMPTY_VALUE, prevMainU = EMPTY_VALUE;
int      prevMainC = 0;

CandItem gCand[]; // conjunto candidato com histerese

// prefixos p/ objetos
string   PREFIX_PRZ    = "PRZ_BOX_";
string   PREFIX_WIN    = "PRZ_WIN_";
string   PREFIX_LINE   = "PRZ_LINE_";     // linhas no modo normal
string   PREFIX_BUGLN  = "PRZ_BUG_LINE_"; // linhas no modo BUG
string   PREFIX_BUGLG  = "PRZ_BUG_LEG_";
string   PREFIX_TDOT   = "PRZ_TDOT_";
string   PREFIX_RTXT_MAIN = "PRZ_RTXT_MAIN_";  // linhas de texto (principal)
string   PREFIX_RTXT_SHDW = "PRZ_RTXT_SHDW_";  // linhas de texto (sombra)

//=============================
// 3) FUNÇÕES DE DESENHO
//=============================
void AddLines(Pivot &seq[], int depthCode, int Ntake,
              double &retr[], double &expa[], double &timp[], bool showTime,
              LineItem &all[])
{
   int sz = ArraySize(seq);
   if(sz<2) return;
   int start = MathMax(1, sz-Ntake);
   for(int i=start; i<sz; i++)
   {
      int      typ     = seq[i].type;
      double   prc     = seq[i].price;
      int      idx     = seq[i].index;
      datetime tcur    = seq[i].time;
      double   prcPrev = seq[i-1].price;
      int      idxPrev = seq[i-1].index;
      datetime tprev   = seq[i-1].time;

      double amp = MathAbs(prc - prcPrev);
      if(amp<=0) continue;

      // linhas por família
      if(typ==1) // topo
      {
         for(int j=0;j<ArraySize(retr);j++)
         {
            double r = retr[j];
            int k = ArraySize(all); ArrayResize(all,k+1);
            all[k].level = prc - amp*r; all[k].depth=depthCode;
            all[k].id = StringFormat("%d_1_RET_%d",idx,j);
         }
         for(int j=0;j<ArraySize(expa);j++)
         {
            double r = expa[j];
            int k = ArraySize(all); ArrayResize(all,k+1);
            all[k].level = prc + amp*r; all[k].depth=depthCode;
            all[k].id = StringFormat("%d_1_EXP_%d",idx,j);
         }
      }
      else      // fundo
      {
         for(int j=0;j<ArraySize(retr);j++)
         {
            double r = retr[j];
            int k = ArraySize(all); ArrayResize(all,k+1);
            all[k].level = prc + amp*r; all[k].depth=depthCode;
            all[k].id = StringFormat("%d_-1_RET_%d",idx,j);
         }
         for(int j=0;j<ArraySize(expa);j++)
         {
            double r = expa[j];
            int k = ArraySize(all); ArrayResize(all,k+1);
            all[k].level = prc - amp*r; all[k].depth=depthCode;
            all[k].id = StringFormat("%d_-1_EXP_%d",idx,j);
         }
      }

      // bolinhas de tempo (sempre pra frente)
      if(showTime)
      {
         // Índices cronológicos (0=mais antigo), então cresce com o tempo:
         // distância positiva = idx - idxPrev
         int lenBars = (idx - idxPrev);
         if(lenBars>0)
         {
            for(int j=0;j<ArraySize(timp);j++)
            {
               double tr = timp[j];
               int barsFwd = (int)MathRound(lenBars * tr);
               datetime tProj = tcur + (datetime)(barsFwd * PeriodSeconds(_Period));
               string nm = StringFormat("%s%d_%d_%d", PREFIX_TDOT, depthCode, idx, j);
               if(ObjectFind(0,nm)==-1)
               {
                  ObjectCreate(0,nm,OBJ_TEXT,0,tProj,prc);
                  ObjectSetInteger(0,nm,OBJPROP_COLOR,ColorTempo);
                  ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,8);
                  ObjectSetString (0,nm,OBJPROP_FONT,"Wingdings");
                  ObjectSetString (0,nm,OBJPROP_TEXT,"l"); // círculo pequeno
                  ObjectSetInteger(0,nm,OBJPROP_ANCHOR,ANCHOR_CENTER);
               }
            }
         }
      }
   }
}

void DrawLegs(Pivot &seq[], int depthCode, int Ntake, int maxLegsLocal)
{
   int sz=ArraySize(seq);
   if(sz<2) return;
   int start = MathMax(1, sz-Ntake);
   int cnt=0;
   for(int i=start;i<sz;i++)
   {
      if(cnt>=maxLegsLocal) break;
      string nm = StringFormat("%s%d_%d", PREFIX_BUGLG, depthCode, i);
      if(ObjectFind(0,nm)!=-1) ObjectDelete(0,nm);
      color c = (depthCode==2 ? ColorP2 : ColorP1);
      ObjectCreate(0,nm,OBJ_TREND,0, seq[i-1].time, seq[i-1].price, seq[i].time, seq[i].price);
      ObjectSetInteger(0,nm,OBJPROP_COLOR,c);
      ObjectSetInteger(0,nm,OBJPROP_WIDTH,2);
      cnt++;
   }
}

void DrawLegsWindow(Pivot &seq[], int depthCode, int Ntake, int maxLegsLocal, datetime tMin)
{
   int sz=ArraySize(seq);
   if(sz<2) return;
   int start = MathMax(1, sz-Ntake);
   int cnt=0;
   for(int i=start;i<sz;i++)
   {
      if(seq[i].time < tMin) continue; // ignora segmentos muito antigos (fora da janela à direita)
      if(cnt>=maxLegsLocal) break;
      string nm = StringFormat("%s%d_%d", PREFIX_BUGLG, depthCode, i);
      if(ObjectFind(0,nm)!=-1) ObjectDelete(0,nm);
      color c = (depthCode==2 ? ColorP2 : ColorP1);
      ObjectCreate(0,nm,OBJ_TREND,0, seq[i-1].time, seq[i-1].price, seq[i].time, seq[i].price);
      ObjectSetInteger(0,nm,OBJPROP_COLOR,c);
      ObjectSetInteger(0,nm,OBJPROP_WIDTH,2);
      cnt++;
   }
}

// Recorta pivôs para a janela à direita (t >= tMin) mantendo 1 pivô anterior
void SlicePivotsByTime(const Pivot &src[], datetime tMin, Pivot &dst[])
{
   ArrayResize(dst,0);
   int n = ArraySize(src);
   if(n==0) return;
   int firstIn=-1;
   for(int i=0;i<n;i++) if(src[i].time>=tMin){ firstIn=i; break; }
   if(firstIn==-1){ return; } // nenhum dentro da janela
   int start = MathMax(0, firstIn-1); // inclui 1 anterior para manter a perna de entrada
   int m = n - start;
   ArrayResize(dst, m);
   for(int j=0;j<m;j++) dst[j] = src[start+j];
}

//=============================
// 4) ONINIT / ONDEINIT
//=============================
int OnInit()
{
   // ATR via iCustom no timeframe D1 (não de outra maneira)
   // Caminho relativo ao diretório MQL5/Indicators
   hATR = iCustom(_Symbol, PERIOD_D1, "Fibonnaci\\ATR_D1_Custom", ATR_Period_D1);
   if(hATR==INVALID_HANDLE)
   {
      Print("Erro ao criar handle iCustom(ATR_D1_Custom) no D1");
      return(INIT_FAILED);
   }
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason)
{
   if(hATR!=INVALID_HANDLE) IndicatorRelease(hATR);
   int total = ObjectsTotal(0,0,-1);
   for(int i=total-1;i>=0;i--)
   {
      string name = ObjectName(0,i);
      if(StringFind(name,PREFIX_PRZ,0)==0 ||
         StringFind(name,PREFIX_WIN,0)==0 ||
         StringFind(name,PREFIX_LINE,0)==0 ||
         StringFind(name,PREFIX_BUGLN,0)==0 ||
         StringFind(name,PREFIX_BUGLG,0)==0 ||
         StringFind(name,PREFIX_TDOT,0)==0)
         ObjectDelete(0,name);
   }
   Comment("");
}
void SetLabelText(const string name,const string txt,color col,int x,int y,const string font,int size,ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER)
{
   if(ObjectFind(0,name)==-1)
   {
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   }
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetString (0,name,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetString (0,name,OBJPROP_FONT, font);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
}

void SetRectLabelText(const string name,const string txt,color col,int x,int y,
                      const string font,int size,int w,int h,bool bgTransparent,color bg,
                      ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER)
{
   if(ObjectFind(0,name)==-1)
   {
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   }
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetString (0,name,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetString (0,name,OBJPROP_FONT, font);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   // Fundo: usa clrNONE para simular transparência quando solicitado
   color bgEff = (bgTransparent ? clrNONE : bg);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bgEff);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_FILL,true);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   // Oculta da lista/seleção
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
}

void SetRectBG(const string name,int x,int y,int w,int h,bool bgTransparent,color bg,
               ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER)
{
   if(ObjectFind(0,name)==-1)
   {
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   }
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   // fundo efetivo
   color bgEff = (bgTransparent ? clrNONE : bg);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bgEff);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_FILL,true);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   // sem texto no retângulo; texto será desenhado como OBJ_LABEL sobreposto
   ObjectSetString(0,name,OBJPROP_TEXT,"");
}

int CountLines(const string &s)
{
   int len = StringLen(s);
   if(len<=0) return 0;
   int lines=1;
   for(int i=0;i<len;i++) if(StringGetCharacter(s,i)=='\n') lines++;
   return lines;
}

int AutoHeightPx(const string &txt,int fontSize,double lineSpacing,int padY)
{
   int lines = CountLines(txt);
   if(lines<=0) lines = 1;
   double h = (double)lines * (double)fontSize * lineSpacing + (double)padY;
   return (int)MathCeil(h);
}

void UpdateRulesPanel(const string txt)
{
   bool useRect = (RulesUseRectLabel && !RulesBgTransparent);
   // altura estimada pelo nº de linhas
   int hh = RulesHeightPx;
   if(RulesAutoHeight || hh<=0)
      hh = AutoHeightPx(txt, RulesFontSize, RulesLineSpacing, RulesPadY);

   // fundo retangular (opcional)
   if(useRect)
      SetRectBG("PRZ_RULES_BG", RulesX, RulesY, RulesWidthPx, hh, RulesBgTransparent, RulesBgColor, CORNER_LEFT_UPPER);
   else
      ObjectDelete(0,"PRZ_RULES_BG");

   // texto multi‑linha: uma label por linha
   DrawTextLines(PREFIX_RTXT_MAIN, PREFIX_RTXT_SHDW, txt, RulesX, RulesY,
                 RulesTextColor, RulesFontName, RulesFontSize, RulesLineSpacing, RulesShadow);
}

void ClearRulesPanel()
{
   ObjectDelete(0,"PRZ_RULES_MAIN");
   ObjectDelete(0,"PRZ_RULES_SHADOW");
   ObjectDelete(0,"PRZ_RULES_BG");
}

void DeleteByPrefix(const string prefix)
{
   int total = ObjectsTotal(0,0,-1);
   for(int i=total-1;i>=0;i--)
   {
      string nm = ObjectName(0,i);
      if(StringFind(nm,prefix,0)==0)
         ObjectDelete(0,nm);
   }
}

void DrawTextLines(const string baseMain,const string baseShdw,const string txt,
                   int x,int y,color col,const string font,int fsize,double lineSpacing,bool drawShadow)
{
   // apaga linhas antigas
   DeleteByPrefix(baseMain);
   DeleteByPrefix(baseShdw);

   string lines[];
   int n = StringSplit(txt,'\n',lines);
   if(n<=0){ ArrayResize(lines,1); lines[0]=txt; n=1; }
   int lh = (int)MathCeil((double)fsize * lineSpacing);
   for(int i=0;i<n;i++)
   {
      int yi = y + i*lh;
      if(drawShadow)
      {
         string nmS = baseShdw + IntegerToString(i);
         SetLabelText(nmS, lines[i], clrBlack, x+1, yi+1, font, fsize, CORNER_LEFT_UPPER);
      }
      string nmM = baseMain + IntegerToString(i);
      SetLabelText(nmM, lines[i], col, x, yi, font, fsize, CORNER_LEFT_UPPER);
   }
}



//=============================
// 5) ONCALCULATE
//=============================
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
   if(rates_total<MathMax(P1_k,P2_k)*2+10) return(prev_calculated);

   double atrBuf[];
   if(CopyBuffer(hATR,0,0,1,atrBuf)<=0)
   {
      Comment("ATR(D1) indisponível (carregue histórico D1 do símbolo).");
      return(prev_calculated);
   }
   double atrD1 = atrBuf[0];
   if(!MathIsValidNumber(atrD1) || atrD1<=0)
   {
      Comment("ATR(D1) = 0/NaN (carregue histórico D1 do símbolo).");
      return(prev_calculated);
   }


   // réguas
   double Jin  = JanelaPctATR * atrD1;
   double Jout = (JanelaPctATR + HistereseExtraPctATR) * atrD1;
   double W    = LarguraPRZ_PctATR * atrD1;

   // arrays cronológicos próprios (0 = mais antigo)
   int n=rates_total;
   double hi[], lo[]; datetime tm[];
   ArrayResize(hi,n); ArrayResize(lo,n); ArrayResize(tm,n);
   for(int i=0;i<n;i++){ hi[i]=high[n-1-i]; lo[i]=low[n-1-i]; tm[i]=time[n-1-i]; }

   //--- 5.1 Pivôs P1 e P2 com alternância
   Pivot p1[]; Pivot p2[];
   // P1 (cronológico: 0 = mais antigo)
   for(int i=P1_k; i<=n-1-P1_k; i++)
   {
      if(IsPivotTop(hi,i,P1_k))
      { Pivot pv; pv.type=1; pv.price=hi[i]; pv.index=i; pv.time=tm[i]; AppendPivotWithAlternation(p1,pv); }
      if(IsPivotBottom(lo,i,P1_k))
      { Pivot pv; pv.type=-1; pv.price=lo[i]; pv.index=i; pv.time=tm[i]; AppendPivotWithAlternation(p1,pv); }
   }
   // P2 (cronológico)
   for(int i=P2_k; i<=n-1-P2_k; i++)
   {
      if(IsPivotTop(hi,i,P2_k))
      { Pivot pv; pv.type=1; pv.price=hi[i]; pv.index=i; pv.time=tm[i]; AppendPivotWithAlternation(p2,pv); }
      if(IsPivotBottom(lo,i,P2_k))
      { Pivot pv; pv.type=-1; pv.price=lo[i]; pv.index=i; pv.time=tm[i]; AppendPivotWithAlternation(p2,pv); }
   }

   //--- 5.2 listas de razões
   double retr[], expa[], timp[];
   ParseFloatList(Retracoes, retr);
   ParseFloatList(Expansoes, expa);
   ParseFloatList(ProjTempo, timp);
   bool showTime = (ArraySize(timp)>0);

   //--- 5.3 Todas as linhas (não desenhar aqui; só no modo bug)
   //     Recorte para a janela da direita (t>=tL) para focar no presente
   datetime tR0 = time[0];
   datetime tL0 = tR0 - (datetime)(WindowBars * PeriodSeconds(_Period));
   Pivot p1w[], p2w[];
   SlicePivotsByTime(p1, tL0, p1w);
   SlicePivotsByTime(p2, tL0, p2w);

   LineItem all[]; ArrayResize(all,0);
   AddLines(p1w,1,N_P1,retr,expa,timp,showTime,all);
   AddLines(p2w,2,N_P2,retr,expa,timp,showTime,all);

   //--- 5.4 Histerese de entrada/saída (candidatas)
   double px = close[0];
   CandItem newCand[]; ArrayResize(newCand,0);
   for(int i=0;i<ArraySize(all);i++)
   {
      string id  = all[i].id;
      double lvl = all[i].level;
      int pos = FindCandById(gCand,id);
      bool wasOn = (pos>=0 ? gCand[pos].on : false);
      double d = MathAbs(lvl - px);
      bool turnOn  = (!wasOn && d<=Jin);
      bool turnOff = (wasOn && d>Jout);
      bool nowOn   = wasOn;
      if(turnOn)  nowOn=true;
      if(turnOff) nowOn=false;
      int k = ArraySize(newCand);
      ArrayResize(newCand,k+1);
      newCand[k].id=id; newCand[k].level=lvl; newCand[k].on=nowOn; newCand[k].depth=all[i].depth;
   }
   // copiar para memória persistente
   int szNew = ArraySize(newCand);
   ArrayResize(gCand,szNew);
   for(int i=0;i<szNew;i++) gCand[i]=newCand[i];

   // níveis ativos
   double S[]; ArrayResize(S,0);
   for(int i=0;i<ArraySize(gCand);i++)
      if(gCand[i].on)
      { int k=ArraySize(S); ArrayResize(S,k+1); S[k]=gCand[i].level; }

   // ordenar (forma simples para evitar mensagens sobre parâmetros)
   if(ArraySize(S)>1) ArraySort(S);

   //--- 5.5 PRZ Top-K (sem overlap)
   double Ls[], Us[]; int Cs[];
   ArrayResize(Ls,0); ArrayResize(Us,0); ArrayResize(Cs,0);

   double tmp[]; int ns = ArraySize(S);
   ArrayResize(tmp,ns);
   for(int i=0;i<ns;i++) tmp[i]=S[i];

   for(int k=0;k<TopK_PRZ;k++)
   {
      double Lb,Ub; int Cb,iL,iU;
      BestDensity(tmp,W,Lb,Ub,Cb,iL,iU);
      if(Cb>=Nmin_PRZ && Lb!=EMPTY_VALUE)
      {
         int m=ArraySize(Ls);
         ArrayResize(Ls,m+1); ArrayResize(Us,m+1); ArrayResize(Cs,m+1);
         Ls[m]=Lb; Us[m]=Ub; Cs[m]=Cb;
         RemoveRange(tmp,Lb,Ub);
      }
      else break;
   }

   //--- 5.6 Histerese para PRZ principal (#1)
   double mainL=EMPTY_VALUE, mainU=EMPTY_VALUE; int mainC=0;
   if(ArraySize(Ls)>0)
   {
      double candL = Ls[0], candU = Us[0]; int candC = Cs[0];
      int contPrev = 0;
      if(prevMainL!=EMPTY_VALUE && prevMainU!=EMPTY_VALUE)
         contPrev = CountInRange(S,prevMainL,prevMainU);
      double ov = 0.0;
      if(prevMainL!=EMPTY_VALUE && prevMainU!=EMPTY_VALUE)
         ov = Overlap(prevMainL,prevMainU,candL,candU);
      bool keepPrev = (contPrev>=Nmin_PRZ) || (ov >= Tau_OverlapFrac*W);
      bool swapOK   = (candC >= contPrev + DeltaCont);

      if(prevMainL!=EMPTY_VALUE && keepPrev && !swapOK)
      { mainL=prevMainL; mainU=prevMainU; mainC=contPrev; }
      else
      { mainL=candL; mainU=candU; mainC=candC; }
   }
   prevMainL = mainL; prevMainU = mainU; prevMainC = mainC;

   //=============================
   // 6) DESENHO: PRZs e Janela
   //=============================
   // apaga PRZs/Janela antigos (mantém bolinhas de tempo)
   int total = ObjectsTotal(0,0,-1);
   for(int i=total-1;i>=0;i--)
   {
      string nm = ObjectName(0,i);
      if(StringFind(nm,PREFIX_PRZ,0)==0) ObjectDelete(0,nm);
      if(StringFind(nm,PREFIX_WIN,0)==0) ObjectDelete(0,nm);
      // sempre limpa linhas do modo normal para redesenhar
      if(StringFind(nm,PREFIX_LINE,0)==0) ObjectDelete(0,nm);
      // limpa SEMPRE as linhas e pernas do modo bug para não acumular no passado
      if(StringFind(nm,PREFIX_BUGLN,0)==0) ObjectDelete(0,nm);
      if(StringFind(nm,PREFIX_BUGLG,0)==0) ObjectDelete(0,nm);
   }

   // janela centrada
   if(ShowWindow)
   {
      datetime tR = time[0];
      datetime tL = tR - (datetime)(WindowBars * PeriodSeconds(_Period));
      string nmw = PREFIX_WIN + "MAIN";
      ObjectCreate(0,nmw,OBJ_RECTANGLE,0,tL,close[0]+Jin,tR,close[0]-Jin);
      ObjectSetInteger(0,nmw,OBJPROP_COLOR,ColorWindow);
      ObjectSetInteger(0,nmw,OBJPROP_BACK,true);
      ObjectSetInteger(0,nmw,OBJPROP_FILL,true);
      ObjectSetInteger(0,nmw,OBJPROP_WIDTH,1);
   }

   // PRZ principal
   if(mainL!=EMPTY_VALUE && mainU!=EMPTY_VALUE)
   {
      datetime tR = time[0];
      datetime tL = tR - (datetime)(WindowBars * PeriodSeconds(_Period));
      string nm = StringFormat("%sMAIN", PREFIX_PRZ);
      ObjectCreate(0,nm,OBJ_RECTANGLE,0,tL,mainU,tR,mainL);
      ObjectSetInteger(0,nm,OBJPROP_COLOR,ColorPRZ);
      ObjectSetInteger(0,nm,OBJPROP_BACK,true);
      ObjectSetInteger(0,nm,OBJPROP_FILL,true);
      ObjectSetInteger(0,nm,OBJPROP_WIDTH,1);
   }

   // PRZs adicionais
   if(ArraySize(Ls)>1)
   {
      for(int i=1;i<ArraySize(Ls);i++)
      {
         datetime tR = time[0];
         datetime tL = tR - (datetime)(WindowBars * PeriodSeconds(_Period));
         string nm = StringFormat("%s%d", PREFIX_PRZ, i);
         ObjectCreate(0,nm,OBJ_RECTANGLE,0,tL,Us[i],tR,Ls[i]);
         ObjectSetInteger(0,nm,OBJPROP_COLOR,ColorPRZ);
         ObjectSetInteger(0,nm,OBJPROP_BACK,true);
         ObjectSetInteger(0,nm,OBJPROP_FILL,true);
         ObjectSetInteger(0,nm,OBJPROP_WIDTH,1);
      }
   }

   //=============================
   // 6.5) LINHAS NO MODO NORMAL (se habilitadas)
   //=============================
   if(ShowLines)
   {
      int count=0;
      for(int i=0;i<ArraySize(gCand) && count<MaxLines;i++)
      {
         if(!gCand[i].on) continue; // só linhas ativas (perto do preço atual)
         string nm = StringFormat("%s%d", PREFIX_LINE, count);
         if(ObjectFind(0,nm)!=-1) ObjectDelete(0,nm);
         ObjectCreate(0,nm,OBJ_HLINE,0,0,gCand[i].level);
         color c = (gCand[i].depth==2 ? ColorP2 : ColorP1);
         ObjectSetInteger(0,nm,OBJPROP_COLOR,c);
         ObjectSetInteger(0,nm,OBJPROP_WIDTH,1);
         count++;
      }
   }

   //=============================
   // 7) MODO BUG: TODAS AS LINHAS + PERNAS
   //=============================
   if(BugMode)
   {
      datetime tR = time[0];
      datetime tL = tR - (datetime)(WindowBars * PeriodSeconds(_Period));
      // linhas
      int cntL = MathMin(ArraySize(all), BugMaxLines);
      for(int i=0;i<cntL;i++)
      {
         string nm = StringFormat("%s%d", PREFIX_BUGLN, i);
         if(ObjectFind(0,nm)!=-1) ObjectDelete(0,nm);
         ObjectCreate(0,nm,OBJ_HLINE,0,0,all[i].level);
         color c = (all[i].depth==2 ? ColorP2 : ColorP1);
         ObjectSetInteger(0,nm,OBJPROP_COLOR,c);
         ObjectSetInteger(0,nm,OBJPROP_WIDTH,1);
      }
      // pernas (somente dentro da janela à direita)
      DrawLegsWindow(p1,1,N_P1,BugMaxLegs,tL);
      DrawLegsWindow(p2,2,N_P2,BugMaxLegs,tL);
   }
   int dbgP1 = ArraySize(p1w);
   int dbgP2 = ArraySize(p2w);
   int dbgAll = 0; // linhas totais geradas
   // 'all' é local — recalcule rápido:
   {
      LineItem all_dbg[]; ArrayResize(all_dbg,0);
      AddLines(p1w,1,N_P1,retr,expa,timp,showTime,all_dbg);
      AddLines(p2w,2,N_P2,retr,expa,timp,showTime,all_dbg);
      dbgAll = ArraySize(all_dbg);
   }
   int dbgCand = 0;
   for(int i=0;i<ArraySize(gCand);i++) if(gCand[i].on) dbgCand++;
   int dbgS = 0;
   // 'S' também é local; reconta candidatas ON:
   for(int i=0;i<ArraySize(gCand);i++) if(gCand[i].on) dbgS++;
   
   int dbgK = 0; // nº de PRZs candidatas
   // reconta Top-K com as mesmas regras
   {
      // copie S para vetor temporário
      double Sdbg[]; ArrayResize(Sdbg,0);
      for(int i=0;i<ArraySize(gCand);i++) if(gCand[i].on){ int k=ArraySize(Sdbg); ArrayResize(Sdbg,k+1); Sdbg[k]=gCand[i].level; }
      if(ArraySize(Sdbg)>1) ArraySort(Sdbg);
      double tmpdbg[]; int ns = ArraySize(Sdbg);
      ArrayResize(tmpdbg,ns); for(int i=0;i<ns;i++) tmpdbg[i]=Sdbg[i];
      for(int k=0;k<TopK_PRZ;k++)
      {
         double Lb,Ub; int Cb,iL,iU;
         BestDensity(tmpdbg,W,Lb,Ub,Cb,iL,iU);
         if(Cb>=Nmin_PRZ && Lb!=EMPTY_VALUE){ dbgK++; RemoveRange(tmpdbg,Lb,Ub); } else break;
      }
   }

   //=============================
   // 8) TEXTO DAS REGRAS / PAINEL
   //=============================
   if(ShowRules)
   {
      string txt;
      txt  = StringFormat("Pivôs: P1 k=%d | P2 k=%d\n", P1_k, P2_k);
      txt += StringFormat("Últimos pivôs: P1 N=%d | P2 N=%d\n", N_P1, N_P2);
      txt += StringFormat("ATR(D1 p=%d)  J_in=%.2f ATR, J_out=J_in+%.2f ATR | W=%.2f ATR\n",
                          ATR_Period_D1, JanelaPctATR, HistereseExtraPctATR, LarguraPRZ_PctATR);
      // Quebra a linha longa em três para não cortar numa tela estreita
      txt += "Razões RET: ["+Retracoes+"]\n";
      txt += "Razões EXP: ["+Expansoes+"]\n";
      txt += "Tempo: ["+ProjTempo+"]\n";
      txt += StringFormat("PRZ: N_min=%d  Top-K=%d  Δ_cont=%d  τ=%.2f\n", Nmin_PRZ, TopK_PRZ, DeltaCont, Tau_OverlapFrac);
      txt += StringFormat("Exibição: janela=%s | Modo BUG=%s\n",
                          (ShowWindow?"ON":"OFF"), (BugMode?"ON":"OFF"));
      // Observação longa quebrada em duas linhas para evitar corte
      txt += "Obs.: nada parte de bid/ask;\n";
      txt += "projeções sempre de topos/fundos e suas pernas.";
   
      // Sempre desenha via labels para evitar corte/rolagem do Comment
      UpdateRulesPanel(txt);
      Comment("");
   }
   else
   {
      ClearRulesPanel();
      Comment("");
   }
   

   return(rates_total);
}
