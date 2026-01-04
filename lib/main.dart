import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

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
        scaffoldBackgroundColor: Color(0xFF1E1E1E),
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
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
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

      // Request initial data
      _requestMarkets();
      _requestAccountInfo();
    } catch (e) {
      print('WebSocket connection error: $e');
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> data) {
    if (data.containsKey('active_symbols')) {
      _updateMarkets(data['active_symbols']);
    } else if (data.containsKey('candles')) {
      _updateCandles(data['candles']);
    } else if (data.containsKey('balance')) {
      setState(() {
        _accountInfo['balance'] = data['balance']['balance'];
      });
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

  void _requestAccountInfo() {
    // Demo account info
    setState(() {
      _accountInfo = {
        'balance': 10000.00,
        'equity': 10000.00,
        'margin': 0.00,
        'free_margin': 10000.00,
        'currency': 'USD',
      };
    });
  }

  void _updateMarkets(List<dynamic> symbols) {
    setState(() {
      _markets = symbols.take(20).map((s) => Market(
        symbol: s['symbol'] ?? '',
        displayName: s['display_name'] ?? '',
        price: 0.0,
        change: 0.0,
      )).toList();
    });

    // Subscribe to ticks for each market
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
      final quote = tick['quote'];
      
      final index = _markets.indexWhere((m) => m.symbol == symbol);
      if (index != -1) {
        final oldPrice = _markets[index].price;
        _markets[index].price = quote.toDouble();
        if (oldPrice > 0) {
          _markets[index].change = ((quote - oldPrice) / oldPrice) * 100;
        }
      }
    });
  }

  void _updateCandles(List<dynamic> candles) {
    setState(() {
      _candles = candles.map((c) => CandleData(
        time: DateTime.fromMillisecondsSinceEpoch(c['epoch'] * 1000),
        open: c['open'].toDouble(),
        high: c['high'].toDouble(),
        low: c['low'].toDouble(),
        close: c['close'].toDouble(),
      )).toList();
    });
  }

  void _requestCandles(String symbol) {
    _channel.sink.add(jsonEncode({
      'ticks_history': symbol,
      'adjust_start_time': 1,
      'count': 50,
      'end': 'latest',
      'start': 1,
      'style': 'candles',
      'granularity': 60
    }));
  }

  @override
  void dispose() {
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
      ),
      TradeScreen(accountInfo: _accountInfo),
      HistoryScreen(history: _history),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Color(0xFF2A2A2A),
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Quotes'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Charts'),
          BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Trade'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}

// Quotes Screen
class QuotesScreen extends StatelessWidget {
  final List<Market> markets;
  final bool isConnected;

  QuotesScreen({required this.markets, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Market Quotes'),
        actions: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isConnected ? 'CONNECTED' : 'DISCONNECTED',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: markets.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: markets.length,
              itemBuilder: (context, index) {
                final market = markets[index];
                final isPositive = market.change >= 0;
                
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: Color(0xFF2A2A2A),
                  child: ListTile(
                    title: Text(
                      market.displayName,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(market.symbol),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          market.price.toStringAsFixed(5),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${isPositive ? '+' : ''}${market.change.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: isPositive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// Charts Screen
class ChartsScreen extends StatefulWidget {
  final List<CandleData> candles;
  final Function(String) onSymbolSelected;
  final List<Market> markets;

  ChartsScreen({
    required this.candles,
    required this.onSymbolSelected,
    required this.markets,
  });

  @override
  _ChartsScreenState createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  String? _selectedSymbol;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Charts'),
        actions: [
          if (widget.markets.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(Icons.filter_list),
              onSelected: (symbol) {
                setState(() {
                  _selectedSymbol = symbol;
                });
                widget.onSymbolSelected(symbol);
              },
              itemBuilder: (context) => widget.markets.map((m) {
                return PopupMenuItem(
                  value: m.symbol,
                  child: Text(m.displayName),
                );
              }).toList(),
            ),
        ],
      ),
      body: widget.candles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Mifidiana marché ho jerena ny chart',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : Padding(
              padding: EdgeInsets.all(16),
              child: CandlestickChart(candles: widget.candles),
            ),
    );
  }
}

// Candlestick Chart Widget
class CandlestickChart extends StatelessWidget {
  final List<CandleData> candles;

  CandlestickChart({required this.candles});

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) return SizedBox();

    final spots = candles.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.close);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: Colors.blue,
            barWidth: 2,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}

// Trade Screen
class TradeScreen extends StatelessWidget {
  final Map<String, dynamic> accountInfo;

  TradeScreen({required this.accountInfo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Trade')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Color(0xFF2A2A2A),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow('Balance', 
                      '\$${accountInfo['balance']?.toStringAsFixed(2) ?? '0.00'}'),
                    Divider(color: Colors.grey),
                    _buildInfoRow('Equity', 
                      '\$${accountInfo['equity']?.toStringAsFixed(2) ?? '0.00'}'),
                    Divider(color: Colors.grey),
                    _buildInfoRow('Marge', 
                      '\$${accountInfo['margin']?.toStringAsFixed(2) ?? '0.00'}'),
                    Divider(color: Colors.grey),
                    _buildInfoRow('Marge Libre', 
                      '\$${accountInfo['free_margin']?.toStringAsFixed(2) ?? '0.00'}'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Ordre vaovao',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Card(
              color: Color(0xFF2A2A2A),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Symbol',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Volume',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {},
                            child: Text('BUY'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {},
                            child: Text('SELL'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// History Screen
class HistoryScreen extends StatelessWidget {
  final List<Trade> history;

  HistoryScreen({required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('History')),
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Tsy misy historique',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final trade = history[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: Color(0xFF2A2A2A),
                  child: ListTile(
                    title: Text(trade.symbol),
                    subtitle: Text(trade.date),
                    trailing: Text(
                      '\$${trade.profit.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: trade.profit >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
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

  Market({
    required this.symbol,
    required this.displayName,
    required this.price,
    required this.change,
  });
}

class CandleData {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;

  CandleData({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });
}

class Trade {
  final String symbol;
  final String date;
  final double profit;

  Trade({required this.symbol, required this.date, required this.profit});
}