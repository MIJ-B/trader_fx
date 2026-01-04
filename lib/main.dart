import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'dart:math' as math;

void main() {
  runApp(TradingApp());
}

class TradingApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trading App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Color(0xFF0D1B2A),
        cardColor: Color(0xFF1B263B),
      ),
      home: MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late WebSocketChannel _channel;
  List<Market> _markets = [];
  List<CandleData> _candles = [];
  Map<String, dynamic> _accountInfo = {};
  List<Trade> _history = [];
  List<Position> _openPositions = [];
  bool _isConnected = false;
  String? _selectedSymbol;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _initializeDemoData();
    _startUpdateTimer();
  }

  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_candles.isNotEmpty && _selectedSymbol != null) {
        setState(() {
          final lastCandle = _candles.last;
          final change = (math.Random().nextDouble() - 0.5) * 0.0001;
          final newClose = lastCandle.close + change;
          _candles.last = CandleData(
            time: lastCandle.time,
            open: lastCandle.open,
            high: math.max(lastCandle.high, newClose),
            low: math.min(lastCandle.low, newClose),
            close: newClose,
            volume: lastCandle.volume,
          );
        });
      }
    });
  }

  void _initializeDemoData() {
    setState(() {
      _accountInfo = {
        'balance': 10000.00,
        'equity': 10250.00,
        'margin': 500.00,
        'free_margin': 9750.00,
        'margin_level': 2050.00,
        'profit': 250.00,
        'currency': 'USD',
      };

      _history = [
        Trade(
          symbol: 'EUR/USD',
          date: '2026-01-04 10:30',
          profit: 125.50,
          type: 'BUY',
          volume: 0.1,
          openPrice: 1.0850,
          closePrice: 1.0875,
        ),
        Trade(
          symbol: 'GBP/USD',
          date: '2026-01-04 09:15',
          profit: -45.20,
          type: 'SELL',
          volume: 0.05,
          openPrice: 1.2650,
          closePrice: 1.2660,
        ),
        Trade(
          symbol: 'USD/JPY',
          date: '2026-01-03 16:45',
          profit: 89.30,
          type: 'BUY',
          volume: 0.2,
          openPrice: 149.50,
          closePrice: 149.95,
        ),
      ];

      _openPositions = [
        Position(
          id: '001',
          symbol: 'EUR/USD',
          type: 'BUY',
          volume: 0.1,
          openPrice: 1.0865,
          currentPrice: 1.0870,
          profit: 5.00,
          openTime: '2026-01-04 12:30',
        ),
        Position(
          id: '002',
          symbol: 'GBP/USD',
          type: 'SELL',
          volume: 0.05,
          openPrice: 1.2645,
          currentPrice: 1.2640,
          profit: 2.50,
          openTime: '2026-01-04 12:45',
        ),
      ];
    });
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('wss://ws.binaryws.com/websockets/v3?app_id=1089'),
      );
      
      setState(() {
        _isConnected = true;
      });

      _channel.stream.listen((message) {
        final data = jsonDecode(message);
        _handleWebSocketMessage(data);
      }, onError: (error) {
        setState(() {
          _isConnected = false;
        });
      });

      _requestMarkets();
    } catch (e) {
      print('WebSocket error: $e');
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> data) {
    if (data.containsKey('active_symbols')) {
      _updateMarkets(data['active_symbols']);
    } else if (data.containsKey('ohlc')) {
      _updateCandles(data['ohlc']);
    } else if (data.containsKey('tick')) {
      _updateTick(data['tick']);
    }
  }

  void _requestMarkets() {
    _channel.sink.add(jsonEncode({
      'active_symbols': 'brief',
      'product_type': 'basic'
    }));
  }

  void _updateMarkets(List<dynamic> symbols) {
    setState(() {
      _markets = symbols.where((s) => 
        s['market'] == 'forex' || s['market'] == 'synthetic_index'
      ).take(30).map((s) => Market(
        symbol: s['symbol'] ?? '',
        displayName: s['display_name'] ?? '',
        price: 0.0,
        change: 0.0,
        bid: 0.0,
        ask: 0.0,
        spread: 0.0,
      )).toList();
    });

    for (var market in _markets) {
      _channel.sink.add(jsonEncode({
        'ticks': market.symbol,
        'subscribe': 1
      }));
    }
  }

  void _updateTick(Map<String, dynamic> tick) {
    setState(() {
      final symbol = tick['symbol'];
      final quote = tick['quote']?.toDouble() ?? 0.0;
      
      final index = _markets.indexWhere((m) => m.symbol == symbol);
      if (index != -1) {
        final oldPrice = _markets[index].price;
        _markets[index].price = quote;
        _markets[index].bid = quote - 0.0001;
        _markets[index].ask = quote + 0.0001;
        _markets[index].spread = 0.0002;
        
        if (oldPrice > 0) {
          _markets[index].change = ((quote - oldPrice) / oldPrice) * 100;
        }
      }
    });
  }

  void _requestCandles(String symbol) {
    setState(() {
      _selectedSymbol = symbol;
    });

    _channel.sink.add(jsonEncode({
      'ticks_history': symbol,
      'adjust_start_time': 1,
      'count': 100,
      'end': 'latest',
      'start': 1,
      'style': 'candles',
      'granularity': 60
    }));
  }

  void _updateCandles(Map<String, dynamic> ohlcData) {
    if (ohlcData.containsKey('candles')) {
      List<dynamic> candles = ohlcData['candles'];
      setState(() {
        _candles = candles.map((c) => CandleData(
          time: DateTime.fromMillisecondsSinceEpoch(c['epoch'] * 1000),
          open: c['open'].toDouble(),
          high: c['high'].toDouble(),
          low: c['low'].toDouble(),
          close: c['close'].toDouble(),
          volume: 1000.0,
        )).toList();
      });
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      QuotesScreen(markets: _markets, isConnected: _isConnected),
      ChartsScreen(
        candles: _candles,
        onSymbolSelected: _requestCandles,
        markets: _markets,
        selectedSymbol: _selectedSymbol,
      ),
      TradeScreen(
        accountInfo: _accountInfo,
        openPositions: _openPositions,
        markets: _markets,
      ),
      HistoryScreen(history: _history),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Color(0xFF1B263B),
        selectedItemColor: Color(0xFF00D9FF),
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Quotes'),
          BottomNavigationBarItem(icon: Icon(Icons.candlestick_chart), label: 'Charts'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Trade'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}

// Quotes Screen with enhanced features
class QuotesScreen extends StatefulWidget {
  final List<Market> markets;
  final bool isConnected;

  QuotesScreen({required this.markets, required this.isConnected});

  @override
  _QuotesScreenState createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  String _searchQuery = '';
  String _filterType = 'All';

  @override
  Widget build(BuildContext context) {
    final filteredMarkets = widget.markets.where((m) {
      final matchesSearch = m.displayName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Market Quotes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF1B263B),
        elevation: 0,
        actions: [
          Container(
            margin: EdgeInsets.all(8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isConnected ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  widget.isConnected ? 'LIVE' : 'OFFLINE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Color(0xFF1B263B),
            padding: EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Hikaroka symbol...',
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Color(0xFF0D1B2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredMarkets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF00D9FF)),
                        SizedBox(height: 16),
                        Text('Mampiditra données...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(8),
                    itemCount: filteredMarkets.length,
                    itemBuilder: (context, index) {
                      final market = filteredMarkets[index];
                      final isPositive = market.change >= 0;
                      
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        color: Color(0xFF1B263B),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isPositive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isPositive ? Icons.trending_up : Icons.trending_down,
                              color: isPositive ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(
                            market.displayName,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4),
                              Text(market.symbol, style: TextStyle(color: Colors.grey)),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('Bid: ${market.bid.toStringAsFixed(5)} ', 
                                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text('Ask: ${market.ask.toStringAsFixed(5)}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                market.price.toStringAsFixed(5),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isPositive ? Colors.green : Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${isPositive ? '+' : ''}${market.change.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Enhanced Charts Screen with real candlestick chart
class ChartsScreen extends StatefulWidget {
  final List<CandleData> candles;
  final Function(String) onSymbolSelected;
  final List<Market> markets;
  final String? selectedSymbol;

  ChartsScreen({
    required this.candles,
    required this.onSymbolSelected,
    required this.markets,
    this.selectedSymbol,
  });

  @override
  _ChartsScreenState createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  String _timeframe = '1H';
  bool _showVolume = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectedSymbol ?? 'Charts', 
          style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF1B263B),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list),
            onSelected: (symbol) {
              widget.onSymbolSelected(symbol);
            },
            itemBuilder: (context) => widget.markets.map((m) {
              return PopupMenuItem(
                value: m.symbol,
                child: Text(m.displayName),
              );
            }).toList(),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.access_time),
            onSelected: (tf) => setState(() => _timeframe = tf),
            itemBuilder: (context) => [
              PopupMenuItem(value: '1M', child: Text('1 Minute')),
              PopupMenuItem(value: '5M', child: Text('5 Minutes')),
              PopupMenuItem(value: '15M', child: Text('15 Minutes')),
              PopupMenuItem(value: '1H', child: Text('1 Hour')),
              PopupMenuItem(value: '4H', child: Text('4 Hours')),
              PopupMenuItem(value: '1D', child: Text('1 Day')),
            ],
          ),
        ],
      ),
      body: widget.candles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.candlestick_chart, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'Mifidiana marché ho jerena ny chart',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Tsindrio ny icon filter ambony',
                    style: TextStyle(color: Colors.grey.withOpacity(0.6), fontSize: 14),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  color: Color(0xFF1B263B),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPriceInfo('Open', widget.candles.last.open),
                      _buildPriceInfo('High', widget.candles.last.high),
                      _buildPriceInfo('Low', widget.candles.last.low),
                      _buildPriceInfo('Close', widget.candles.last.close),
                    ],
                  ),
                ),
                Expanded(
                  child: CandlestickChart(
                    candles: widget.candles,
                    showVolume: _showVolume,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text('Volume:', style: TextStyle(color: Colors.grey)),
                      Switch(
                        value: _showVolume,
                        onChanged: (val) => setState(() => _showVolume = val),
                        activeColor: Color(0xFF00D9FF),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPriceInfo(String label, double value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 12)),
        SizedBox(height: 4),
        Text(
          value.toStringAsFixed(5),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}

// Real Candlestick Chart Widget
class CandlestickChart extends StatelessWidget {
  final List<CandleData> candles;
  final bool showVolume;

  CandlestickChart({required this.candles, this.showVolume = true});

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) return SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = showVolume ? constraints.maxHeight * 0.7 : constraints.maxHeight;
        final volumeHeight = constraints.maxHeight * 0.3;

        return Column(
          children: [
            Container(
              height: chartHeight,
              child: CustomPaint(
                size: Size(constraints.maxWidth, chartHeight),
                painter: CandlestickPainter(candles: candles),
              ),
            ),
            if (showVolume)
              Container(
                height: volumeHeight,
                child: CustomPaint(
                  size: Size(constraints.maxWidth, volumeHeight),
                  painter: VolumePainter(candles: candles),
                ),
              ),
          ],
        );
      },
    );
  }
}

class CandlestickPainter extends CustomPainter {
  final List<CandleData> candles;

  CandlestickPainter({required this.candles});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final maxPrice = candles.map((c) => c.high).reduce(math.max);
    final minPrice = candles.map((c) => c.low).reduce(math.min);
    final priceRange = maxPrice - minPrice;
    
    final candleWidth = size.width / candles.length * 0.7;
    final spacing = size.width / candles.length;

    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final x = i * spacing + spacing / 2;
      
      final openY = size.height - ((candle.open - minPrice) / priceRange * size.height);
      final closeY = size.height - ((candle.close - minPrice) / priceRange * size.height);
      final highY = size.height - ((candle.high - minPrice) / priceRange * size.height);
      final lowY = size.height - ((candle.low - minPrice) / priceRange * size.height);

      final isGreen = candle.close >= candle.open;
      final color = isGreen ? Colors.green : Colors.red;

      // Draw wick
      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(x, highY), Offset(x, lowY), wickPaint);

      // Draw body
      final bodyPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      
      final bodyTop = math.min(openY, closeY);
      final bodyBottom = math.max(openY, closeY);
      final bodyHeight = (bodyBottom - bodyTop).abs();
      
      canvas.drawRect(
        Rect.fromLTWH(x - candleWidth / 2, bodyTop, candleWidth, 
          bodyHeight > 1 ? bodyHeight : 1),
        bodyPaint,
      );
    }

    // Draw grid
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 0.5;
    
    for (int i = 0; i <= 5; i++) {
      final y = size.height / 5 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class VolumePainter extends CustomPainter {
  final List<CandleData> candles;

  VolumePainter({required this.candles});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final maxVolume = candles.map((c) => c.volume).reduce(math.max);
    final barWidth = size.width / candles.length * 0.7;
    final spacing = size.width / candles.length;

    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final x = i * spacing + spacing / 2;
      final barHeight = (candle.volume / maxVolume) * size.height;
      
      final isGreen = candle.close >= candle.open;
      final paint = Paint()
        ..color = (isGreen ? Colors.green : Colors.red).withOpacity(0.5);

      canvas.drawRect(
        Rect.fromLTWH(x - barWidth / 2, size.height - barHeight, barWidth, barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Enhanced Trade Screen
class TradeScreen extends StatefulWidget {
  final Map<String, dynamic> accountInfo;
  final List<Position> openPositions;
  final List<Market> markets;

  TradeScreen({
    required this.accountInfo,
    required this.openPositions,
    required this.markets,
  });

  @override
  _TradeScreenState createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> {
  String? _selectedSymbol;
  double _volume = 0.01;
  String _orderType = 'Market';

  @override
  Widget build(BuildContext context) {
    final totalProfit = widget.openPositions.fold<double>(
      0, (sum, pos) => sum + pos.profit);

    return Scaffold(
      appBar: AppBar(
        title: Text('Trade', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF1B263B),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Account Summary Card
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B263B), Color(0xFF0D1B2A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text('BALANCE', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  SizedBox(height: 8),
                  Text(
                    '\$${widget.accountInfo['balance']?.toStringAsFixed(2) ?? '0.00'}',
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, 
                      color: Color(0xFF00D9FF)),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildAccountStat('Equity', widget.accountInfo['equity']),
                      _buildAccountStat('Marge', widget.accountInfo['margin']),
                      _buildAccountStat('Libre', widget.accountInfo['free_margin']),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: totalProfit >= 0 ? Colors.green.withOpacity(0.2) : 
                        Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          totalProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                          color: totalProfit >= 0 ? Colors.green : Colors.red,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'P/L: \$${totalProfit.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: totalProfit >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Open Positions
            if (widget.openPositions.isNotEmpty)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'POSITIONS OUVERTES',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 12),
                    ...widget.openPositions.map((pos) => _buildPositionCard(pos)),
                  ],
                ),
              ),

            SizedBox(height: 24),

            // New Order Form
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF1B263B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ORDRE VAOVAO',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _selectedSymbol,
                    decoration: InputDecoration(
                      labelText: 'Symbol',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Color(0xFF0D1B2A),
                    ),
                    items: widget.markets.map((m) => DropdownMenuItem(
                      value: m.symbol,
                      child: Text(m.displayName),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedSymbol = val),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Volume (Lot)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Color(0xFF0D1B2A),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => _volume = double.tryParse(val) ?? 0.01,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _orderType,
                          decoration: InputDecoration(
                            labelText: 'Type',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Color(0xFF0D1B2A),
                          ),
                          items: ['Market', 'Limit', 'Stop'].map((type) => 
                            DropdownMenuItem(value: type, child: Text(type))
                          ).toList(),
                          onChanged: (val) => setState(() => _orderType = val!),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _selectedSymbol != null ? () {
                            _showOrderConfirmation(context, 'BUY');
                          } : null,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text('BUY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _selectedSymbol != null ? () {
                            _showOrderConfirmation(context, 'SELL');
                          } : null,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text('SELL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountStat(String label, dynamic value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 12)),
        SizedBox(height: 4),
        Text(
          '\$${value?.toStringAsFixed(2) ?? '0.00'}',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildPositionCard(Position pos) {
    final isProfit = pos.profit >= 0;
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      color: Color(0xFF0D1B2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pos.symbol,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: pos.type == 'BUY' ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        pos.type,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isProfit ? '+' : ''}\$${pos.profit.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isProfit ? Colors.green : Colors.red,
                      ),
                    ),
                    Text(
                      'Vol: ${pos.volume}',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Open: ${pos.openPrice.toStringAsFixed(5)}', 
                  style: TextStyle(color: Colors.grey)),
                Text('Current: ${pos.currentPrice.toStringAsFixed(5)}',
                  style: TextStyle(color: Colors.grey)),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showClosePosition(context, pos),
                    child: Text('CLOSE'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderConfirmation(BuildContext context, String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1B263B),
        title: Text('Confirmation'),
        content: Text(
          'Hanao ordre $type ${_selectedSymbol ?? ''}\nVolume: $_volume lot?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ordre $type nalefa!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('CONFIRM'),
            style: ElevatedButton.styleFrom(
              backgroundColor: type == 'BUY' ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  void _showClosePosition(BuildContext context, Position pos) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1B263B),
        title: Text('Close Position'),
        content: Text('Hanakatona ny position ${pos.symbol}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Position nakatona!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('CLOSE'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}

// Enhanced History Screen
class HistoryScreen extends StatefulWidget {
  final List<Trade> history;

  HistoryScreen({required this.history});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filterType = 'All';

  @override
  Widget build(BuildContext context) {
    final filteredHistory = _filterType == 'All' 
      ? widget.history
      : widget.history.where((t) => t.type == _filterType).toList();

    final totalProfit = widget.history.fold<double>(0, (sum, t) => sum + t.profit);
    final winRate = widget.history.isEmpty ? 0.0 : 
      (widget.history.where((t) => t.profit > 0).length / widget.history.length * 100);

    return Scaffold(
      appBar: AppBar(
        title: Text('History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF1B263B),
      ),
      body: Column(
        children: [
          // Statistics Card
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B263B), Color(0xFF0D1B2A)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text('TOTAL PROFIT/LOSS', 
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
                SizedBox(height: 8),
                Text(
                  '\$${totalProfit.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: totalProfit >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Trades', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('${widget.history.length}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Win Rate', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('${winRate.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                            color: Color(0xFF00D9FF))),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Wins', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('${widget.history.where((t) => t.profit > 0).length}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                            color: Colors.green)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filter Chips
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('All'),
                SizedBox(width: 8),
                _buildFilterChip('BUY'),
                SizedBox(width: 8),
                _buildFilterChip('SELL'),
              ],
            ),
          ),

          SizedBox(height: 16),

          // History List
          Expanded(
            child: filteredHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Tsy misy historique',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredHistory.length,
                    itemBuilder: (context, index) {
                      final trade = filteredHistory[index];
                      final isProfit = trade.profit >= 0;
                      
                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        color: Color(0xFF1B263B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: trade.type == 'BUY' ? 
                                            Colors.green : Colors.red,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          trade.type,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        trade.symbol,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${isProfit ? '+' : ''}\$${trade.profit.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isProfit ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    trade.date,
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                  Text(
                                    'Vol: ${trade.volume}',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Open: ${trade.openPrice.toStringAsFixed(5)}',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                  Text(
                                    'Close: ${trade.closePrice.toStringAsFixed(5)}',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filterType == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterType = label);
      },
      selectedColor: Color(0xFF00D9FF),
      backgroundColor: Color(0xFF1B263B),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

// Data Models
class Market {
  final String symbol;
  final String displayName;
  double price;
  double change;
  double bid;
  double ask;
  double spread;

  Market({
    required this.symbol,
    required this.displayName,
    required this.price,
    required this.change,
    required this.bid,
    required this.ask,
    required this.spread,
  });
}

class CandleData {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  CandleData({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });
}

class Trade {
  final String symbol;
  final String date;
  final double profit;
  final String type;
  final double volume;
  final double openPrice;
  final double closePrice;

  Trade({
    required this.symbol,
    required this.date,
    required this.profit,
    required this.type,
    required this.volume,
    required this.openPrice,
    required this.closePrice,
  });
}

class Position {
  final String id;
  final String symbol;
  final String type;
  final double volume;
  final double openPrice;
  final double currentPrice;
  final double profit;
  final String openTime;

  Position({
    required this.id,
    required this.symbol,
    required this.type,
    required this.volume,
    required this.openPrice,
    required this.currentPrice,
    required this.profit,
    required this.openTime,
  });
}