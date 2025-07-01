## 📊RSI Surf Scout - A Multi-Symbol Multi-Timeframe Trading Expert Advisor

RSI Surf Scout is an advanced automated trading system that combines RSI momentum analysis with EMA trend filtering and sophisticated risk management. Designed for prop firm traders and professional accounts, it manages multiple symbols across multiple timeframes simultaneously with built-in prop firm protections and comprehensive trade journaling.

---

## ✨ Key Features

### 🔥 Core Trading Strategy
- **RSI Momentum Detection**: Advanced RSI analysis for entry signals
- **EMA Trend Filtering**: Trades only in the direction of the dominant trend
- **ATR-Based Volatility Filter**: Dynamic position sizing based on market volatility
- **Volume Confirmation**: Optional volume analysis for signal validation
- **Multi-Symbol Trading**: Supports 12 major symbols including forex, commodities, and crypto
- **Multi-Timeframe Analysis**: Operates on M5, M15, and M30 simultaneously

### 🛡️ Professional Risk Management
- **Fixed Dollar Risk**: Consistent $50 risk per trade (configurable)
- **Dynamic Position Sizing**: Automatically calculates lot sizes based on stop loss distance
- **Trailing Stop System**: Intelligent profit protection with $50 increment trailing
- **Prop Firm Protection**: Built-in daily loss limits and drawdown controls
- **Session Management**: Respects trading hours (Lagos time GMT+1)

### 📈 Advanced Features
- **Limit Order System**: Places limit orders with automatic expiration
- **Symbol-Specific Settings**: Customized parameters for each trading instrument
- **Trade Journal**: Comprehensive CSV logging of all trading activity
- **Context Persistence**: Saves and restores EA state across restarts
- **Spread Filtering**: Avoids trading during high spread conditions

---

## 🎯 Supported Trading Instruments

| Symbol | Type | Optimized For |
|--------|------|---------------|
| XAUUSD | Gold | High volatility precious metal |
| BTCUSD | Bitcoin | Cryptocurrency momentum |
| US30 | Index | Stock index trending |
| USDJPY | Forex | Major currency pair |
| GBPJPY | Forex | Volatile cross pair |
| EURGBP | Forex | Range-bound pair |
| ETHUSD | Ethereum | Altcoin momentum |
| USOIL | Oil | Commodity trending |
| AUDJPY | Forex | Commodity currency |
| XAGUSD | Silver | Precious metal |
| EURUSD | Forex | Most liquid pair |
| GBPUSD | Forex | Volatile major |

---

## ⚙️ Configurable Parameters

### 🔧 Risk Management Parameters

| Parameter | Description | Low Risk | Moderate | Aggressive |
|-----------|-------------|----------|----------|------------|
| **RiskPerTrade** | Fixed dollar risk per trade | $25 | $50 | $100 |
| **RiskRewardRatio** | Target profit multiplier | 3:1 | 5:1 | 8:1 |
| **TrailingStopATRFactor** | ATR multiplier for trailing | 1.5 | 1.0 | 0.8 |
| **OrderExpirationBars** | Bars until limit order expires | 10 | 5 | 3 |
| **MinLotSize** | Minimum position size | 0.01 | 0.01 | 0.02 |
| **MaxLotSize** | Maximum position size | 0.5 | 1.0 | 2.0 |
| **Slippage** | Maximum slippage in points | 5 | 3 | 2 |

### 📊 Strategy Parameters

| Parameter | Description | Conservative | Balanced | Aggressive |
|-----------|-------------|--------------|----------|------------|
| **EmaPeriod** | EMA period for trend filter | 100 | 50 | 21 |
| **RsiPeriod** | RSI calculation period | 21 | 14 | 9 |
| **RsiUpper** | RSI overbought level | 75 | 70 | 65 |
| **RsiLower** | RSI oversold level | 25 | 30 | 35 |
| **EnableVolumeFilter** | Use volume confirmation | true | true | false |
| **VolumeMultiplier** | Volume threshold multiplier | 2.5 | 1.8 | 1.2 |
| **EntryThresholdFactor** | ATR entry sensitivity | 0.5 | 0.3 | 0.15 |
| **MinEmaSlope** | Minimum EMA slope filter | 10.0 | 5.0 | 2.0 |

### 🎛️ Trading Settings

| Parameter | Description | Conservative | Standard | Aggressive |
|-----------|-------------|--------------|----------|------------|
| **EnableBuy** | Allow long positions | true | true | true |
| **EnableSell** | Allow short positions | true | true | true |
| **MaxTradesPerSymbolTF** | Max trades per symbol/TF | 1 | 1 | 2 |
| **MaxGlobalTrades** | Total simultaneous trades | 8 | 15 | 25 |
| **MinBarsBetweenTrades** | Spacing between trades | 10 | 5 | 3 |
| **LimitOrderDistance** | Pips from market | 3.0 | 2.0 | 1.0 |

### 🕐 Session Settings (Lagos Time GMT+1)

| Parameter | Description | Default Value |
|-----------|-------------|---------------|
| **EnableSession** | Enable trading session | true |
| **SundayOpen** | Sunday open hour | 22 |
| **SundayOpenMin** | Sunday open minute | 15 |
| **DailyClose** | Daily close hour | 21 |
| **DailyCloseMin** | Daily close minute | 45 |

### 🛡️ Prop Firm Protection

| Parameter | Description | FTMO/MFF | The5ers | Funded Next |
|-----------|-------------|----------|----------|-------------|
| **DailyMaxLoss** | Maximum daily loss | $300 | $500 | $400 |
| **DailyProfitTarget** | Daily profit target | $600 | $1000 | $800 |
| **MaxDrawdownPercent** | Account drawdown limit | 4% | 5% | 6% |
| **MaxSpreadMultiplier** | Spread filter multiplier | 2.5 | 3.0 | 3.5 |

### 📝 Trade Journal Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| **EnableTradeJournal** | Enable trade logging | true |
| **JournalFileName** | CSV log filename | "TradeJournal.csv" |

---

## 🚀 Installation & Setup

### 1. **File Placement**
- Place `RSI_Surf_Scout_EA_v1.1.mq5` in your MetaTrader 5 `Experts` folder
- Compile the EA in MetaEditor

### 2. **Chart Setup**
- Attach to any chart (EA manages all symbols internally)
- Recommended: Use EURUSD M5 chart as master chart

### 3. **Parameter Configuration**
- Choose risk profile: Conservative, Moderate, or Aggressive
- Adjust parameters according to your prop firm rules
- Enable/disable specific trading sessions

### 4. **Prop Firm Compliance**
- Set appropriate daily loss limits
- Configure maximum drawdown percentage
- Adjust position sizing for account size

---

## 📊 Trading Logic

### Entry Conditions
**Long (Buy) Entry:**
- RSI rising from oversold levels
- Price above EMA (trend confirmation)
- Fast ATR < Slow ATR (volatility filter)
- EMA slope > minimum threshold
- Volume confirmation (if enabled)

**Short (Sell) Entry:**
- RSI falling from overbought levels
- Price below EMA (trend confirmation)
- Fast ATR < Slow ATR (volatility filter)
- EMA slope < negative threshold
- Volume confirmation (if enabled)

### Position Management
- **Initial Stop Loss**: ATR-based dynamic calculation
- **Take Profit**: Risk/Reward ratio multiplier
- **Trailing Stop**: $50 increment progression system
- **Position Sizing**: Fixed dollar risk with dynamic lot calculation

---

## 🔍 Performance Optimization

### Symbol-Specific Optimization
Each symbol has pre-configured settings optimized for its characteristics:
- **Gold/Silver**: Higher SL factor for volatility
- **Crypto**: Wider RSI bands, no volume filter
- **Forex Majors**: Standard settings with volume confirmation
- **Indices**: Balanced approach with trend following

### Timeframe Diversification
- **M5**: Scalping opportunities
- **M15**: Swing trading
- **M30**: Position trading

---

## 📈 Risk Management Features

### 🛡️ Multi-Layer Protection
1. **Position-Level**: ATR-based stop losses
2. **Daily-Level**: Maximum loss and profit targets
3. **Account-Level**: Drawdown percentage limits
4. **Session-Level**: Time-based trading windows

### 💰 Profit Protection
- Trailing stops activate after first $50 profit
- Scales up with additional $50 increments
- Maintains risk/reward ratio throughout trade lifecycle

---

## 📊 Monitoring & Analytics

### Trade Journal Features
- Complete trade history in CSV format
- Real-time profit/loss tracking
- Symbol and timeframe performance analysis
- Risk metrics and compliance monitoring

### Context Persistence
- Saves EA state between restarts
- Maintains trade history and statistics
- Preserves symbol-specific data

---

## ⚠️ Important Notes

### Prop Firm Compliance
- **Always test on demo first**
- Verify parameters meet your prop firm's rules
- Monitor daily loss limits carefully
- Adjust position sizes for account scaling

### System Requirements
- MetaTrader 5 build 3280 or higher
- Stable internet connection
- VPS recommended for 24/7 operation
- Minimum 4GB RAM for multi-symbol operation

### Risk Disclaimer
- Past performance does not guarantee future results
- Trading involves substantial risk of loss
- Only trade with capital you can afford to lose
- Always use proper risk management

---

## 🎯 Quick Start Configurations

### For Beginners (Low Risk)
```
RiskPerTrade = 25
RiskRewardRatio = 3
MaxGlobalTrades = 8
DailyMaxLoss = 200
MaxDrawdownPercent = 3
```

### For Experienced Traders (Moderate)
```
RiskPerTrade = 50
RiskRewardRatio = 5
MaxGlobalTrades = 15
DailyMaxLoss = 500
MaxDrawdownPercent = 5
```

### For Advanced Traders (Aggressive)
```
RiskPerTrade = 100
RiskRewardRatio = 8
MaxGlobalTrades = 25
DailyMaxLoss = 800
MaxDrawdownPercent = 6
```

---

## 📞 Support & Updates

**Version**: 1.1  
**Copyright**: © Christley Olubela 2025
**Contact**: olubelachristley@gmail.com  


*Trade responsibly and always prioritize risk management over profits.*
