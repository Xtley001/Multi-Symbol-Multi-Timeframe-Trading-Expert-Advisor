//+------------------------------------------------------------------+
//|                                      RSI Surf Scout EA v1.3.mq5 |
//|                              Copyright © 2025, Expert Advisors Ltd |
//|                                             olubelachristley@mail.com |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, Expert Advisors Ltd"
#property link      "olubelachristley@gail.com"
#property version   "1.30"

// Include necessary libraries
#include <Trade/Trade.mqh>
#include <Math/Stat/Math.mqh>
#include <Trade/DealInfo.mqh>
#include <Arrays/ArrayObj.mqh>

// Risk Management Parameters
input double RiskPerTrade = 50;           // Fixed $ risk per trade
input double RiskRewardRatio = 5;         // Risk/Reward ratio
input double TrailingStopATRFactor = 1.0; // Trailing SL ATR factor
input int OrderExpirationMinutes = 60;    // Minutes until order expires
input double MinLotSize = 0.01;           // Minimum lot size
input double MaxLotSize = 1.0;            // Maximum lot size
input int Slippage = 3;                   // Slippage in points

// Strategy Parameters
input int EmaPeriod = 50;                 // EMA period for trend filter
input int RsiPeriod = 14;                 // RSI period
input double RsiUpper = 70.0;             // RSI upper level
input double RsiLower = 30.0;             // RSI lower level
input bool EnableVolumeFilter = true;     // Enable volume confirmation
input double VolumeMultiplier = 1.8;      // Min volume vs average
input double EntryThresholdFactor = 0.3;  // ATR entry threshold factor
input double MinEmaSlope = 5.0;           // Minimum EMA slope (points)

// Trading Settings
input bool EnableBuy = true;              // Enable Buy Trades
input bool EnableSell = true;             // Enable Sell Trades
input int MaxTradesPerSymbolTF = 1;       // Max trades per symbol/timeframe
input int MaxGlobalTrades = 15;           // Max simultaneous trades
input int MinBarsBetweenTrades = 5;       // Min bars between trades
input double LimitOrderDistance = 2.0;    // Pips from market for limit orders

// Session Settings (Lagos Time = GMT+1)
input bool EnableSession = true;          // Enable Trading Session
input int SundayOpen = 22;                // Sunday Open Hour (22:15)
input int SundayOpenMin = 15;             // Sunday Open Minute
input int DailyClose = 21;                // Daily Close Hour (21:45)
input int DailyCloseMin = 45;             // Daily Close Minute

// Prop Firm Protections
input double DailyMaxLoss = 500;          // Max daily loss ($)
input double DailyProfitTarget = 1000;    // Daily profit target ($)
input double MaxDrawdownPercent = 5.0;    // Max account drawdown (%)
input double MaxSpreadMultiplier = 3.0;   // Max spread multiplier

// Trade Journal
input bool EnableTradeJournal = true;     // Enable trade logging
input string JournalFileName = "TradeJournal.csv"; // Journal filename

// Trading symbols
string Symbols[] = {"XAUUSD","BTCUSD","US30","USDJPY","GBPJPY","EURGBP","ETHUSD","USOIL","AUDJPY","XAGUSD","EURUSD","GBPUSD"};
ENUM_TIMEFRAMES Timeframes[] = {PERIOD_M5, PERIOD_M15, PERIOD_M30};

// Symbol-specific configuration structure
struct SymbolSettings {
   string symbol;
   double slFactor;               // Stop loss ATR multiplier
   int atr1Period;                // Fast ATR period
   int atr2Period;                // Slow ATR period
   double rsiUpper;               // Custom RSI upper level
   double rsiLower;               // Custom RSI lower level
   double trailingFactor;         // Trailing stop multiplier
   int emaPeriod;                 // Custom EMA period
   bool useVolumeFilter;          // Enable volume filter for symbol
   double entryThresholdFactor;   // Entry threshold multiplier
};

// Preconfigured symbol settings
SymbolSettings settings[12] = {
   {"XAUUSD",   2.0, 10, 20, 70, 30, 1.0, 50, true, 0.25},  // Gold
   {"BTCUSD",   1.5, 14, 26, 75, 25, 1.0, 35, false, 0.4},  // Bitcoin
   {"US30",     1.5, 10, 20, 70, 30, 1.0, 50, true, 0.3},   // US30 Index
   {"USDJPY",   1.5,  8, 14, 70, 30, 1.0, 50, true, 0.2},   // USD/JPY
   {"GBPJPY",   1.5,  8, 14, 70, 30, 1.0, 50, true, 0.2},   // GBP/JPY
   {"EURGBP",   1.5,  8, 14, 70, 30, 1.0, 50, true, 0.2},   // EUR/GBP
   {"ETHUSD",   1.5, 14, 26, 75, 25, 1.0, 35, false, 0.4},  // Ethereum
   {"USOIL",    1.5, 10, 20, 70, 30, 2.0, 50, true, 0.3},   // Oil
   {"AUDJPY",   1.5,  8, 14, 70, 30, 1.0, 50, true, 0.2},   // AUD/JPY
   {"XAGUSD",   2.0, 10, 20, 70, 30, 1.0, 50, true, 0.25},  // Silver
   {"EURUSD",   1.5,  8, 14, 70, 30, 1.0, 50, true, 0.2},   // EUR/USD
   {"GBPUSD",   1.5,  8, 14, 70, 30, 1.0, 50, true, 0.2}    // GBP/USD
};

// Pending Order Management Class
class CPendingOrder : public CObject {
public:
   ulong ticket;                  // Order ticket number
   string symbol;                 // Trading symbol
   ENUM_TIMEFRAMES timeframe;     // Order timeframe
   datetime placementTime;        // Order placement time
   ulong magic;                   // Order magic number
   
   CPendingOrder(ulong t, string s, ENUM_TIMEFRAMES tf, datetime pt, ulong m) :
      ticket(t), symbol(s), timeframe(tf), placementTime(pt), magic(m) {}
};

// Active Orders Collection Class
class CPendingOrderArray : public CArrayObj {
public:
   CPendingOrderArray() { m_free_mode = true; }  // Enable auto-deletion
   
   // Add new pending order to collection
   bool AddOrder(ulong ticket, string symbol, ENUM_TIMEFRAMES tf, datetime time, ulong magic) {
      CPendingOrder* order = new CPendingOrder(ticket, symbol, tf, time, magic);
      return this.Add(order);
   }
   
   // Cleanup invalid or closed orders
   void Cleanup() {
      for(int i = this.Total()-1; i >= 0; i--) {
         CPendingOrder* order = this.At(i);
         if(order == NULL) {
            this.Delete(i);
            continue;
         }
         
         if(!OrderSelect(order.ticket)) {
            this.Delete(i);
            continue;
         }
         
         if(OrderGetInteger(ORDER_STATE) != ORDER_STATE_PLACED) {
            this.Delete(i);
         }
      }
   }
   
   // Check and remove expired orders
   void CheckExpiration() {
      datetime now = TimeCurrent();
      for(int i = this.Total()-1; i >= 0; i--) {
         CPendingOrder* order = this.At(i);
         if(order == NULL) continue;
         
         if(now >= order.placementTime + OrderExpirationMinutes * 60) {
            if(OrderSelect(order.ticket)) {
               trade.OrderDelete(order.ticket);
               Print("Order expired: ", order.ticket, " on ", order.symbol);
            }
            this.Delete(i);
         }
      }
   }
   
   // Count orders by symbol and magic number
   int CountBySymbolMagic(string symbol, ulong magic) {
      int count = 0;
      for(int i = 0; i < this.Total(); i++) {
         CPendingOrder* order = this.At(i);
         if(order != NULL && order.symbol == symbol && order.magic == magic) {
            count++;
         }
      }
      return count;
   }
};

// Global Variables
double equityHigh = 0;                // Account equity high watermark
double equityAtStart = 0;             // Equity at session start
double dailyProfitLoss = 0;            // Daily profit/loss tracking
datetime sessionStart = 0;             // Current session start time
static ulong lastLoggedDealTicket = 0; // Last logged deal ticket
bool contextLoaded = false;            // Context load status

CPendingOrderArray activeOrders;       // Active pending orders
CTrade trade;                          // Global trade object
struct SymbolContext {
   string symbol;                      // Symbol name
   int lastTradeBar[];                 // Last trade bar index per TF
   double atrCurrent[];                // Current ATR value per TF
   datetime lastTradeTime[];           // Last trade time per TF
   int lastProcessedBar[];             // Last processed bar per TF
   datetime lastOrderPlacement[];      // Last order placement time per TF
};
SymbolContext symbolContexts[];        // Per-symbol context
ulong baseMagic = 100000;              // Base magic number (increased)

//+------------------------------------------------------------------+
//| Custom clamp function to replace MathClamp                       |
//+------------------------------------------------------------------+
double Clamp(double value, double minVal, double maxVal) {
   if(value < minVal) return minVal;
   if(value > maxVal) return maxVal;
   return value;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // Configure trade parameters
   trade.SetDeviationInPoints(Slippage);
   
   // Initialize account equity tracking
   equityHigh = AccountInfoDouble(ACCOUNT_EQUITY);
   equityAtStart = equityHigh;
   sessionStart = 0;
   
   // Initialize symbol contexts
   ArrayResize(symbolContexts, ArraySize(Symbols));
   for(int i=0; i<ArraySize(Symbols); i++) {
      symbolContexts[i].symbol = Symbols[i];
      int tfCount = ArraySize(Timeframes);
      ArrayResize(symbolContexts[i].lastTradeBar, tfCount);
      ArrayResize(symbolContexts[i].atrCurrent, tfCount);
      ArrayResize(symbolContexts[i].lastTradeTime, tfCount);
      ArrayResize(symbolContexts[i].lastProcessedBar, tfCount);
      ArrayResize(symbolContexts[i].lastOrderPlacement, tfCount);
      
      // Initialize arrays
      ArrayInitialize(symbolContexts[i].lastTradeBar, -10);
      ArrayInitialize(symbolContexts[i].lastTradeTime, 0);
      ArrayInitialize(symbolContexts[i].lastProcessedBar, 0);
      ArrayInitialize(symbolContexts[i].lastOrderPlacement, 0);
   }
   
   // Load saved context
   if(!contextLoaded && !LoadContextFromFile()) {
      Print("Context not loaded, using default values");
   }
   
   // Rebuild active orders from broker
   RebuildActiveOrders();
   
   // Initialize trade journal
   if(EnableTradeJournal && !InitializeTradeJournal()) {
      return(INIT_FAILED);
   }
   
   // Set timer for periodic checks
   EventSetTimer(5);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Rebuild active orders from broker                                |
//+------------------------------------------------------------------+
void RebuildActiveOrders() {
   int total = OrdersTotal();
   for(int i = 0; i < total; i++) {
      ulong ticket = OrderGetTicket(i);
      if(OrderSelect(ticket)) {
         long magic = OrderGetInteger(ORDER_MAGIC);
         if(magic >= (long)baseMagic && magic < (long)baseMagic + 1200) {
            string symbol = OrderGetString(ORDER_SYMBOL);
            ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            
            if(type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT) {
               datetime time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
               ENUM_TIMEFRAMES tf = PERIOD_CURRENT;
               
               // Determine timeframe from magic number
               int magicOffset = (int)(magic - baseMagic);
               int tfIndex = magicOffset % 100;
               if(tfIndex < ArraySize(Timeframes)) {
                  tf = Timeframes[tfIndex];
               }
               
               activeOrders.AddOrder(ticket, symbol, tf, time, (ulong)magic);
               Print("Rebuilt pending order: ", ticket, " ", symbol, " ", EnumToString(tf));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Save context to file                                             |
//+------------------------------------------------------------------+
bool SaveContextToFile() {
   int handle = FileOpen("EA_Context.bin", FILE_WRITE|FILE_BIN);
   if(handle == INVALID_HANDLE) {
      Print("Failed to save context: ", GetLastError());
      return false;
   }
   
   // Save equity tracking
   FileWriteDouble(handle, equityHigh);
   FileWriteDouble(handle, equityAtStart);
   FileWriteDouble(handle, dailyProfitLoss);
   FileWriteLong(handle, sessionStart);
   FileWriteLong(handle, lastLoggedDealTicket);
   
   // Save symbol contexts
   int symbolCount = ArraySize(symbolContexts);
   FileWriteInteger(handle, symbolCount);
   
   for(int i=0; i<symbolCount; i++) {
      FileWriteString(handle, symbolContexts[i].symbol);
      
      int tfCount = ArraySize(symbolContexts[i].lastTradeBar);
      FileWriteInteger(handle, tfCount);
      
      for(int j=0; j<tfCount; j++) {
         FileWriteInteger(handle, symbolContexts[i].lastTradeBar[j]);
         FileWriteDouble(handle, symbolContexts[i].atrCurrent[j]);
         FileWriteLong(handle, symbolContexts[i].lastTradeTime[j]);
         FileWriteInteger(handle, symbolContexts[i].lastProcessedBar[j]);
         FileWriteLong(handle, symbolContexts[i].lastOrderPlacement[j]);
      }
   }
   
   FileClose(handle);
   return true;
}

//+------------------------------------------------------------------+
//| Load context from file                                           |
//+------------------------------------------------------------------+
bool LoadContextFromFile() {
   int handle = FileOpen("EA_Context.bin", FILE_READ|FILE_BIN);
   if(handle == INVALID_HANDLE) {
      return false;
   }
   
   // Load equity tracking
   equityHigh = FileReadDouble(handle);
   equityAtStart = FileReadDouble(handle);
   dailyProfitLoss = FileReadDouble(handle);
   sessionStart = (datetime)FileReadLong(handle);
   lastLoggedDealTicket = FileReadLong(handle);
   
   // Load symbol contexts
   int symbolCount = FileReadInteger(handle);
   ArrayResize(symbolContexts, symbolCount);
   
   for(int i=0; i<symbolCount; i++) {
      symbolContexts[i].symbol = FileReadString(handle);
      int tfCount = FileReadInteger(handle);
      
      ArrayResize(symbolContexts[i].lastTradeBar, tfCount);
      ArrayResize(symbolContexts[i].atrCurrent, tfCount);
      ArrayResize(symbolContexts[i].lastTradeTime, tfCount);
      ArrayResize(symbolContexts[i].lastProcessedBar, tfCount);
      ArrayResize(symbolContexts[i].lastOrderPlacement, tfCount);
      
      for(int j=0; j<tfCount; j++) {
         symbolContexts[i].lastTradeBar[j] = FileReadInteger(handle);
         symbolContexts[i].atrCurrent[j] = FileReadDouble(handle);
         symbolContexts[i].lastTradeTime[j] = (datetime)FileReadLong(handle);
         symbolContexts[i].lastProcessedBar[j] = FileReadInteger(handle);
         symbolContexts[i].lastOrderPlacement[j] = (datetime)FileReadLong(handle);
      }
   }
   
   FileClose(handle);
   contextLoaded = true;
   return true;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   EventKillTimer();
   SaveContextToFile();
   activeOrders.Clear();
}

//+------------------------------------------------------------------+
//| Trade journal initialization                                     |
//+------------------------------------------------------------------+
bool InitializeTradeJournal() {
   if(!EnableTradeJournal) return true;
   
   int handle = FileOpen(JournalFileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE, ',');
   if(handle == INVALID_HANDLE) {
      Print("Error creating trade journal: ", GetLastError());
      return false;
   }
   
   // Write header if new file
   if(FileSize(handle) == 0) {
      string header = "Time,Symbol,Type,Volume,Price,Profit,Comment,Magic,SL,TP";
      FileWrite(handle, header);
   }
   
   FileClose(handle);
   return true;
}

//+------------------------------------------------------------------+
//| Log deal to journal                                              |
//+------------------------------------------------------------------+
void LogDeal(ulong ticket) {
   if(!EnableTradeJournal || ticket <= lastLoggedDealTicket) return;
   
   if(HistoryDealSelect(ticket)) {
      long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
      
      // Only log our EA's deals
      if(magic < (long)baseMagic || magic >= (long)baseMagic + 1200) return;
      
      datetime time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      int type = (int)HistoryDealGetInteger(ticket, DEAL_TYPE);
      double volume = HistoryDealGetDouble(ticket, DEAL_VOLUME);
      double price = HistoryDealGetDouble(ticket, DEAL_PRICE);
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
      
      // Get SL/TP from position if available
      double sl = 0, tp = 0;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN) {
         if(PositionSelectByTicket(HistoryDealGetInteger(ticket, DEAL_POSITION_ID))) {
            sl = PositionGetDouble(POSITION_SL);
            tp = PositionGetDouble(POSITION_TP);
         }
      }
      
      // Convert type to string
      string typeStr = "";
      switch(type) {
         case DEAL_TYPE_BUY: typeStr = "BUY"; break;
         case DEAL_TYPE_SELL: typeStr = "SELL"; break;
         default: typeStr = "UNKNOWN"; break;
      }
      
      // Prepare data string
      string data = StringFormat("%s,%s,%s,%.2f,%.5f,%.2f,%s,%I64d,%.5f,%.5f",
         TimeToString(time, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
         symbol,
         typeStr,
         volume,
         price,
         profit,
         comment,
         magic,
         sl,
         tp
      );
      
      // Write to journal
      int handle = FileOpen(JournalFileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE, ',');
      if(handle != INVALID_HANDLE) {
         FileSeek(handle, 0, SEEK_END);
         FileWrite(handle, data);
         FileClose(handle);
         lastLoggedDealTicket = ticket;
      }
      else {
         Print("Journal write error: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllTrades() {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) {
         // Use global trade object to close position
         trade.PositionClose(ticket);
         Print("Emergency closure: Position #", ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| OnTrade event handler                                            |
//+------------------------------------------------------------------+
void OnTrade() {
   if(!EnableTradeJournal) return;
   
   // Select trade history since last logged deal
   HistorySelect(lastLoggedDealTicket, TimeCurrent() + 60);
   
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++) {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > lastLoggedDealTicket) {
         LogDeal(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Timer event handler                                              |
//+------------------------------------------------------------------+
void OnTimer() {
   static int consecutiveLosses = 0;
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Update equity high watermark
   if(currentEquity > equityHigh) equityHigh = currentEquity;
   
   // Reset daily P&L at session start
   if(IsNewTradingDay()) {
      equityAtStart = currentEquity;
      dailyProfitLoss = 0;
      consecutiveLosses = 0;
   }
   else {
      // Calculate current daily P&L
      dailyProfitLoss = currentEquity - equityAtStart;
   }
   
   // Clean up pending orders
   activeOrders.Cleanup();
   activeOrders.CheckExpiration();
   
   // Prop firm risk checks - emergency closure
   double drawdown = (equityHigh - currentEquity)/equityHigh*100;
   if(dailyProfitLoss <= -DailyMaxLoss || drawdown >= MaxDrawdownPercent) {
      Print("Risk limit breached - closing all trades");
      CloseAllTrades();
      return;
   }
   
   // Circuit breaker for consecutive losses
   if(consecutiveLosses >= 3) {
      Print("Consecutive loss limit reached: ", consecutiveLosses);
      return;
   }
   
   // Skip processing if session not active
   if(EnableSession && !IsTradingSession()) return;
   
   // Process only symbols/timeframes with new bars
   for(int s=0; s<ArraySize(Symbols); s++) {
      for(int t=0; t<ArraySize(Timeframes); t++) {
         string symbol = Symbols[s];
         ENUM_TIMEFRAMES tf = Timeframes[t];
         
         // Check if symbol exists
         if(!SymbolInfoInteger(symbol, SYMBOL_SELECT)) {
            Print("Symbol not available: ", symbol);
            continue;
         }
         
         int currentBars = iBars(symbol, tf);
         if(currentBars > symbolContexts[s].lastProcessedBar[t]) {
            symbolContexts[s].lastProcessedBar[t] = currentBars;
            ProcessSymbolTimeframe(symbol, tf, s, t);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Trading session functions                                        |
//+------------------------------------------------------------------+
bool IsNewTradingDay() {
   MqlDateTime nowStruct;
   TimeCurrent(nowStruct);
   
   static int lastDay = -1;
   if(nowStruct.day != lastDay) {
      lastDay = nowStruct.day;
      return true;
   }
   return false;
}

bool IsTradingSession() {
   if(!EnableSession) return true;
   
   datetime gmtTime = TimeGMT();
   MqlDateTime gmtStruct;
   TimeToStruct(gmtTime, gmtStruct);
   
   // Convert to Lagos time (GMT+1)
   int lagosHour = (gmtStruct.hour + 1) % 24;
   int lagosDow = gmtStruct.day_of_week;
   int lagosMin = gmtStruct.min;
   
   // Adjust day of week for Sunday
   if(lagosHour < 1) {
      lagosDow = (lagosDow + 6) % 7; // Previous day
   }
   
   // Sunday session starts at 22:15 Lagos time (21:15 GMT)
   if(lagosDow == 0) {
      if(lagosHour < 21 || (lagosHour == 21 && lagosMin < 15)) return false;
      return true;
   }
   // Friday session ends at 21:45 Lagos time (20:45 GMT)
   else if(lagosDow == 5) {
      if(lagosHour > 20 || (lagosHour == 20 && lagosMin >= 45)) return false;
      return true;
   }
   // Saturday - no trading
   else if(lagosDow == 6) {
      return false;
   }
   // Monday-Thursday: full session
   return true;
}

//+------------------------------------------------------------------+
//| Unified Dollar Risk Calculation                                  |
//+------------------------------------------------------------------+
double CalculateDollarRiskPerPoint(string symbol) {
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // Validate inputs
   if(tickSize <= 0 || point <= 0) {
      Print("Invalid ticks: ", symbol, " TickSize=", tickSize, " Point=", point);
      return 0;
   }
   
   double risk = (tickValue * point) / tickSize;
   
   // Fallback for zero values
   if(risk <= 0) {
      risk = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE) * point;
      Print("Using fallback risk calculation for ", symbol, ": ", risk);
   }
   
   return risk;
}

//+------------------------------------------------------------------+
//| Robust Lot Size Calculation                                      |
//+------------------------------------------------------------------+
double CalculateLotSize(string symbol, double entry, double sl, double riskAmount) {
   // Validate inputs
   if(entry <= 0 || sl <= 0 || MathAbs(entry - sl) < 1e-5) {
      Print("Invalid prices: ", symbol, " Entry=", entry, " SL=", sl);
      return 0;
   }
   
   double riskPoints = MathAbs(entry - sl);
   double dollarPerPoint = CalculateDollarRiskPerPoint(symbol);
   if(dollarPerPoint <= 0) return 0;
   
   double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   if(contractSize <= 0) contractSize = 1; // Universal fallback
   
   // Core calculation
   double valuePerPointPerLot = dollarPerPoint * contractSize;
   double riskPerLot = riskPoints * valuePerPointPerLot;
   
   if(riskPerLot <= 0) {
      Print("Invalid risk per lot: ", riskPerLot, " for ", symbol);
      return 0;
   }
   
   double lots = riskAmount / riskPerLot;
   
   // Broker constraints
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step = MathMax(SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP), 0.01);
   
   // Fixed normalization and clamping
   lots = step * MathFloor(lots/step + 1e-7); // Avoid floating point errors
   lots = MathMin(MathMax(lots, MathMax(MinLotSize, minLot)), MathMin(MaxLotSize, maxLot));
   
   // Diagnostic logging
   PrintFormat("Lot calc: %s | Entry:%.5f SL:%.5f | Risk:$%.2f | $/Point:%.5f | Contract:%.2f | Lots:%.3f",
               symbol, entry, sl, riskAmount, dollarPerPoint, contractSize, lots);
               
   return lots;
}

//+------------------------------------------------------------------+
//| Volume Filter (Fixed)                                            |
//+------------------------------------------------------------------+
bool CheckVolumeFilter(string symbol, ENUM_TIMEFRAMES tf) {
   MqlRates rates[];
   if(CopyRates(symbol, tf, 1, 20, rates) < 20) return true;
   
   double totalVolume = 0;
   for(int i=0; i<20; i++) {
      // Add explicit cast to double
      totalVolume += (double)((rates[i].real_volume > 0) ? rates[i].real_volume : rates[i].tick_volume);
   }
   double avgVolume = totalVolume / 20.0;
   
   MqlRates currentRate[1];
   if(CopyRates(symbol, tf, 0, 1, currentRate) < 1) return true;
   
   // Add explicit cast to double
   double currentVol = (double)((currentRate[0].real_volume > 0) ? 
                      currentRate[0].real_volume : currentRate[0].tick_volume);
   
   return (currentVol > avgVolume * VolumeMultiplier);
}

//+------------------------------------------------------------------+
//| Spread Check (Simplified)                                        |
//+------------------------------------------------------------------+
bool CheckSpread(string symbol) {
   long currentSpread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   long avgSpread = SymbolInfoInteger(symbol, SYMBOL_SPREAD_FLOAT);
   return (currentSpread <= avgSpread * MaxSpreadMultiplier);
}

//+------------------------------------------------------------------+
//| Adjust SL/TP for fixed risk                                      |
//+------------------------------------------------------------------+
void AdjustRiskForFixedDollar(string symbol, double &sl, double &tp, double entry, 
                              double lot, bool isBuy, double atrValue, double riskAmount, double rrRatio) 
{
    double dollarPerPoint = CalculateDollarRiskPerPoint(symbol);
    if(dollarPerPoint <= 0) return;
    
    double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    if(contractSize <= 0) contractSize = 1;
    
    double valuePerPointPerLot = dollarPerPoint * contractSize;
    double riskPerPoint = valuePerPointPerLot * lot;
    
    if(riskPerPoint <= 0) {
        Print("Error: Invalid risk per point for ", symbol);
        return;
    }
    
    double requiredRiskPoints = riskAmount / riskPerPoint;
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    if(isBuy) {
        sl = entry - requiredRiskPoints * point;
        tp = entry + (riskAmount * rrRatio) / riskPerPoint * point;
    }
    else {
        sl = entry + requiredRiskPoints * point;
        tp = entry - (riskAmount * rrRatio) / riskPerPoint * point;
    }
    
    PrintFormat("Adjusted SL/TP: %s | Lot:%.3f | Risk:$%.2f | Reward:$%.2f | SL:%.5f | TP:%.5f",
                symbol, lot, riskAmount, riskAmount * rrRatio, sl, tp);
}

//+------------------------------------------------------------------+
//| Validate price levels                                            |
//+------------------------------------------------------------------+
bool ValidatePriceLevels(string symbol, double price, double sl, double tp) {
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minDist = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double freezeLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point;
   
   if(MathAbs(price - sl) < minDist) {
      Print("SL too close to price: ", symbol);
      return false;
   }
   
   if(MathAbs(price - tp) < minDist) {
      Print("TP too close to price: ", symbol);
      return false;
   }
   
   if(MathAbs(sl - tp) < freezeLevel) {
      Print("SL/TP too close: ", symbol);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check available margin                                           |
//+------------------------------------------------------------------+
bool CheckMargin(string symbol, double lots, bool isBuy) {
    double margin;
    double price = isBuy ? SymbolInfoDouble(symbol, SYMBOL_ASK) 
                         : SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // Calculate margin requirement for this specific trade
    if(!OrderCalcMargin(
        isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,  // Use market order type for calculation
        symbol,
        lots,
        price,
        margin
    )) {
        Print("Margin calc error: ", GetLastError());
        return false;
    }
    
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    
    // Conservative check: require 2x margin buffer
    if(margin > freeMargin * 0.5) {
        PrintFormat("Insufficient margin: %s Req: %.2f Free: %.2f", 
                    symbol, margin, freeMargin);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Main processing function                                         |
//+------------------------------------------------------------------+
void ProcessSymbolTimeframe(string symbol, ENUM_TIMEFRAMES tf, int symbolIdx, int tfIdx) {
   // Skip if at max global trades
   if(PositionsTotal() >= MaxGlobalTrades) return;
   
   // Bar check for minimum trade spacing
   int bars = iBars(symbol, tf);
   if(bars - symbolContexts[symbolIdx].lastTradeBar[tfIdx] < MinBarsBetweenTrades) return;
   
   // Initialize with default settings
   double slFactor = settings[0].slFactor;
   double trailingFactor = TrailingStopATRFactor;
   double rsiUpper = RsiUpper;
   double rsiLower = RsiLower;
   int atr1Period = settings[0].atr1Period;
   int atr2Period = settings[0].atr2Period;
   int emaPeriod = EmaPeriod;
   bool useVolumeFilter = EnableVolumeFilter;
   double entryThresholdFactor = EntryThresholdFactor;
   
   // Override with symbol-specific settings
   for(int i=0; i<ArraySize(settings); i++) {
      if(symbol == settings[i].symbol) {
         slFactor = settings[i].slFactor;
         trailingFactor = settings[i].trailingFactor;
         rsiUpper = settings[i].rsiUpper;
         rsiLower = settings[i].rsiLower;
         atr1Period = settings[i].atr1Period;
         atr2Period = settings[i].atr2Period;
         emaPeriod = settings[i].emaPeriod;
         useVolumeFilter = settings[i].useVolumeFilter;
         entryThresholdFactor = settings[i].entryThresholdFactor;
         break;
      }
   }
   
   // Get indicator handles
   int hEma = iMA(symbol, tf, emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   int hAtrFast = iATR(symbol, tf, atr1Period);
   int hAtrSlow = iATR(symbol, tf, atr2Period);
   int hRsi = iRSI(symbol, tf, RsiPeriod, PRICE_CLOSE);
   
   // Validate indicator handles
   if(hEma == INVALID_HANDLE || hAtrFast == INVALID_HANDLE || 
      hAtrSlow == INVALID_HANDLE || hRsi == INVALID_HANDLE) {
      Print("Failed to create indicators for ", symbol);
      return;
   }
   
   // Get indicator values
   double emaValue[2] = {0}; // Current and previous EMA
   double atrFast[2] = {0}; // Current and previous ATR
   double atrSlow[2] = {0}; // Current and previous slow ATR
   double rsi[3] = {0};     // Current and previous RSI
   
   if(CopyBuffer(hEma, 0, 0, 2, emaValue) < 2) {
      IndicatorRelease(hEma);
      IndicatorRelease(hAtrFast);
      IndicatorRelease(hAtrSlow);
      IndicatorRelease(hRsi);
      return;
   }
   if(CopyBuffer(hAtrFast, 0, 0, 2, atrFast) < 2) {
      IndicatorRelease(hEma);
      IndicatorRelease(hAtrFast);
      IndicatorRelease(hAtrSlow);
      IndicatorRelease(hRsi);
      return;
   }
   if(CopyBuffer(hAtrSlow, 0, 0, 2, atrSlow) < 2) {
      IndicatorRelease(hEma);
      IndicatorRelease(hAtrFast);
      IndicatorRelease(hAtrSlow);
      IndicatorRelease(hRsi);
      return;
   }
   if(CopyBuffer(hRsi, 0, 0, 3, rsi) < 3) {
      IndicatorRelease(hEma);
      IndicatorRelease(hAtrFast);
      IndicatorRelease(hAtrSlow);
      IndicatorRelease(hRsi);
      return;
   }
   
   // Get price data
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double close = iClose(symbol, tf, 0);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double atrValue = atrFast[0]; // Use current ATR
   symbolContexts[symbolIdx].atrCurrent[tfIdx] = atrValue;
   
   // Calculate EMA slope
   double emaSlope = (emaValue[0] - emaValue[1]) / point;
   
   // Volume filter (using previous bar)
   bool volumeOK = true;
   if(EnableVolumeFilter && useVolumeFilter) {
      volumeOK = CheckVolumeFilter(symbol, tf);
   }
   
   // Spread check
   if(!CheckSpread(symbol)) {
      Print("High spread detected: ", symbol);
      return;
   }
   
   // Trade conditions (fixed RSI logic)
   bool buyCondition = (EnableBuy && 
                      rsi[0] > rsi[1] &&          // RSI rising
                      rsi[0] < rsiLower &&        // Below oversold
                      close > emaValue[0] &&       // Above EMA
                      atrFast[0] < atrSlow[0] &&  // Volatility filter
                      emaSlope > MinEmaSlope &&    // EMA slope filter
                      volumeOK);                  // Volume confirmation
   
   bool sellCondition = (EnableSell && 
                       rsi[0] < rsi[1] &&         // RSI falling
                       rsi[0] > rsiUpper &&       // Above overbought
                       close < emaValue[0] &&      // Below EMA
                       atrFast[0] < atrSlow[0] && // Volatility filter
                       emaSlope < -MinEmaSlope &&  // EMA slope filter
                       volumeOK);                 // Volume confirmation
   
   // Position management
   ManageExistingPositions(symbol, tf, symbolIdx, tfIdx, trailingFactor);
   
   // Calculate unique magic number
   ulong magic = baseMagic + (ulong)symbolIdx * 100 + (ulong)tfIdx;
   
   // Count existing orders and positions
   int existingOrders = CountOrders(symbol, magic);
   if(existingOrders >= MaxTradesPerSymbolTF) {
      return;
   }
   
   // Dynamic risk calculation
   double dynamicRisk = MathMin(RiskPerTrade, AccountInfoDouble(ACCOUNT_EQUITY)*0.01);
   
   // New trade logic
   if((buyCondition || sellCondition) && existingOrders == 0) 
   {
      // Calculate limit order prices
      double pipSize = point * 10;
      double buyLimitPrice = ask - LimitOrderDistance * pipSize;
      double sellLimitPrice = bid + LimitOrderDistance * pipSize;
      
      // Calculate SL/TP
      double buySl = buyLimitPrice - slFactor * atrValue;
      double buyTp = buyLimitPrice + (slFactor * atrValue * RiskRewardRatio);
      double sellSl = sellLimitPrice + slFactor * atrValue;
      double sellTp = sellLimitPrice - (slFactor * atrValue * RiskRewardRatio);
      
      // Calculate expiration time
      datetime expiration = TimeCurrent() + OrderExpirationMinutes * 60;
      
      if(buyCondition) {
         double lots = CalculateLotSize(symbol, buyLimitPrice, buySl, dynamicRisk);
         
         // Skip if lot size is invalid
         if(lots <= 0) return;
         
         // Always adjust SL/TP for fixed dollar risk
         AdjustRiskForFixedDollar(symbol, buySl, buyTp, buyLimitPrice, lots, true, atrValue, dynamicRisk, RiskRewardRatio);
         
         // Validate price levels
         if(!ValidatePriceLevels(symbol, buyLimitPrice, buySl, buyTp)) return;
         
         // Check margin
        // For buy orders:
if(!CheckMargin(symbol, lots, true)) return;



         trade.SetExpertMagicNumber(magic);
         if(trade.BuyLimit(lots, buyLimitPrice, symbol, buySl, buyTp, ORDER_TIME_SPECIFIED, expiration)) {
            Print("BUY LIMIT placed: ", symbol, 
                  " | Lots: ", lots, 
                  " | Price: ", buyLimitPrice, 
                  " | SL: ", buySl, 
                  " | TP: ", buyTp,
                  " | Risk: $", dynamicRisk,
                  " | Reward: $", dynamicRisk * RiskRewardRatio);
            symbolContexts[symbolIdx].lastTradeBar[tfIdx] = bars;
            symbolContexts[symbolIdx].lastTradeTime[tfIdx] = TimeCurrent();
            activeOrders.AddOrder(trade.ResultOrder(), symbol, tf, TimeCurrent(), magic);
         }
         else {
            Print("BuyLimit failed: ", trade.ResultRetcodeDescription());
         }
      }
      else if(sellCondition) {
         double lots = CalculateLotSize(symbol, sellLimitPrice, sellSl, dynamicRisk);
         
         // Skip if lot size is invalid
         if(lots <= 0) return;
         
         // Always adjust SL/TP for fixed dollar risk
         AdjustRiskForFixedDollar(symbol, sellSl, sellTp, sellLimitPrice, lots, false, atrValue, dynamicRisk, RiskRewardRatio);
         
         // Validate price levels
         if(!ValidatePriceLevels(symbol, sellLimitPrice, sellSl, sellTp)) return;
         
         // Check margin
         
// For sell orders:
if(!CheckMargin(symbol, lots, false)) return;
         
         trade.SetExpertMagicNumber(magic);
         if(trade.SellLimit(lots, sellLimitPrice, symbol, sellSl, sellTp, ORDER_TIME_SPECIFIED, expiration)) {
            Print("SELL LIMIT placed: ", symbol, 
                  " | Lots: ", lots, 
                  " | Price: ", sellLimitPrice, 
                  " | SL: ", sellSl, 
                  " | TP: ", sellTp,
                  " | Risk: $", dynamicRisk,
                  " | Reward: $", dynamicRisk * RiskRewardRatio);
            symbolContexts[symbolIdx].lastTradeBar[tfIdx] = bars;
            symbolContexts[symbolIdx].lastTradeTime[tfIdx] = TimeCurrent();
            activeOrders.AddOrder(trade.ResultOrder(), symbol, tf, TimeCurrent(), magic);
         }
         else {
            Print("SellLimit failed: ", trade.ResultRetcodeDescription());
         }
      }
   }
   
   // Cleanup indicators
   IndicatorRelease(hEma);
   IndicatorRelease(hAtrFast);
   IndicatorRelease(hAtrSlow);
   IndicatorRelease(hRsi);
}

//+------------------------------------------------------------------+
//| Position management                                              |
//+------------------------------------------------------------------+
void ManageExistingPositions(string symbol, ENUM_TIMEFRAMES tf, int symbolIdx, int tfIdx, double trailingFactor) {
   // Declare point variable at function start
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   ulong magic = baseMagic + (ulong)symbolIdx * 100 + (ulong)tfIdx;
   
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      if(PositionGetString(POSITION_SYMBOL) == symbol && 
         PositionGetInteger(POSITION_MAGIC) == (long)magic) 
      {
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSl = PositionGetDouble(POSITION_SL);
         double currentTp = PositionGetDouble(POSITION_TP);
         double profit = PositionGetDouble(POSITION_PROFIT);
         double lotSize = PositionGetDouble(POSITION_VOLUME);
         double newSl = currentSl;
         double newTp = currentTp;
         
         // Calculate dollar risk per point
         double dollarPerPoint = CalculateDollarRiskPerPoint(symbol);
         if(dollarPerPoint == 0) continue;
         
         // Calculate value per point for this position
         double pointValue = lotSize * dollarPerPoint;
         if(pointValue == 0) continue;
         
         // Calculate profit units in $50 increments
         int profitUnits = (int)MathFloor(profit / RiskPerTrade);
         
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            if(profitUnits >= 1) {
               newSl = openPrice + profitUnits * (RiskPerTrade / pointValue) * point;
               
               // Additional ATR-based trailing for commodities
               if(symbol == "XAUUSD" || symbol == "USOIL" || symbol == "XAGUSD") {
                  double atr = symbolContexts[symbolIdx].atrCurrent[tfIdx];
                  newSl = MathMax(newSl, currentPrice - trailingFactor * atr);
               }
               
               // Adjust TP to maintain risk/reward ratio
               double slDistance = openPrice - newSl;
               newTp = openPrice + (slDistance * RiskRewardRatio);
               
               if(newSl > currentSl && newSl < currentPrice) {
                  trade.PositionModify(ticket, newSl, newTp);
               }
            }
         }
         else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
            if(profitUnits >= 1) {
               newSl = openPrice - profitUnits * (RiskPerTrade / pointValue) * point;
               
               // Additional ATR-based trailing for commodities
               if(symbol == "XAUUSD" || symbol == "USOIL" || symbol == "XAGUSD") {
                  double atr = symbolContexts[symbolIdx].atrCurrent[tfIdx];
                  newSl = MathMin(newSl, currentPrice + trailingFactor * atr);
               }
               
               // Adjust TP to maintain risk/reward ratio
               double slDistance = newSl - openPrice;
               newTp = openPrice - (slDistance * RiskRewardRatio);
               
               if((newSl < currentSl || currentSl == 0) && newSl > currentPrice) {
                  trade.PositionModify(ticket, newSl, newTp);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Order counting including pending orders                          |
//+------------------------------------------------------------------+
int CountOrders(string symbol, ulong magic) {
   int count = 0;
   
   // Count open positions
   for(int i=0; i<PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) {
         if(PositionGetString(POSITION_SYMBOL) == symbol && 
            PositionGetInteger(POSITION_MAGIC) == (long)magic) {
            count++;
         }
      }
   }
   
   // Count pending orders
   for(int i=0; i<activeOrders.Total(); i++) {
      CPendingOrder* order = activeOrders.At(i);
      if(order != NULL && order.symbol == symbol && order.magic == magic) {
         count++;
      }
   }
   
   return count;
}
//+------------------------------------------------------------------+