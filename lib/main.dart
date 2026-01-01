import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const TradeAnalyzerApp());
}

class TradeAnalyzerApp extends StatelessWidget {
  const TradeAnalyzerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trade Analyzer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        brightness: Brightness.dark,
      ),
      home: const TradeHomePage(),
    );
  }
}

class Trade {
  final String id;
  final DateTime date;
  final double amount;
  final String type; // 'profit' or 'loss'
  final String description;

  Trade({
    required this.id,
    required this.date,
    required this.amount,
    required this.type,
    required this.description,
  });
}

class TradeHomePage extends StatefulWidget {
  const TradeHomePage({Key? key}) : super(key: key);

  @override
  State<TradeHomePage> createState() => _TradeHomePageState();
}

class _TradeHomePageState extends State<TradeHomePage> {
  List<Trade> trades = [];
  double initialFund = 1000.0;
  String currency = 'USD';
  bool showAddTrade = false;

  // Controllers pour le formulaire
  final TextEditingController amountController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  String selectedType = 'profit';

  Map<String, String> currencySymbols = {
    'USD': '\$',
    'EUR': '€',
    'MGA': 'Ar',
  };

  void addTrade() {
    if (amountController.text.isNotEmpty) {
      setState(() {
        trades.add(Trade(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          date: selectedDate,
          amount: double.parse(amountController.text),
          type: selectedType,
          description: descriptionController.text,
        ));
        amountController.clear();
        descriptionController.clear();
        selectedDate = DateTime.now();
        selectedType = 'profit';
        showAddTrade = false;
      });
    }
  }

  void deleteTrade(String id) {
    setState(() {
      trades.removeWhere((trade) => trade.id == id);
    });
  }

  double getTotalBalance() {
    double total = initialFund;
    for (var trade in trades) {
      if (trade.type == 'profit') {
        total += trade.amount;
      } else {
        total -= trade.amount;
      }
    }
    return total;
  }

  String getWeekNumber(DateTime date) {
    int dayOfYear = int.parse(DateFormat("D").format(date));
    int weekNumber = ((dayOfYear - date.weekday + 10) / 7).floor();
    return '${date.year}-S$weekNumber';
  }

  String getMonthYear(DateTime date) {
    return DateFormat('yyyy-MM').format(date);
  }

  Map<String, Map<String, dynamic>> getWeeklyStats() {
    Map<String, Map<String, dynamic>> stats = {};
    
    for (var trade in trades) {
      String week = getWeekNumber(trade.date);
      if (!stats.containsKey(week)) {
        stats[week] = {
          'profit': 0.0,
          'loss': 0.0,
          'net': 0.0,
          'count': 0,
        };
      }
      
      if (trade.type == 'profit') {
        stats[week]!['profit'] += trade.amount;
        stats[week]!['net'] += trade.amount;
      } else {
        stats[week]!['loss'] += trade.amount;
        stats[week]!['net'] -= trade.amount;
      }
      stats[week]!['count']++;
    }
    
    return stats;
  }

  Map<String, Map<String, dynamic>> getMonthlyStats() {
    Map<String, Map<String, dynamic>> stats = {};
    
    for (var trade in trades) {
      String month = getMonthYear(trade.date);
      if (!stats.containsKey(month)) {
        stats[month] = {
          'profit': 0.0,
          'loss': 0.0,
          'net': 0.0,
          'count': 0,
        };
      }
      
      if (trade.type == 'profit') {
        stats[month]!['profit'] += trade.amount;
        stats[month]!['net'] += trade.amount;
      } else {
        stats[month]!['loss'] += trade.amount;
        stats[month]!['net'] -= trade.amount;
      }
      stats[month]!['count']++;
    }
    
    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final weeklyStats = getWeeklyStats();
    final monthlyStats = getMonthlyStats();
    
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: const Text('Trade Analyzer'),
        backgroundColor: const Color(0xFF16213e),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Configuration
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16213e),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Fonds Initial',
                                style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            TextField(
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white10,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  initialFund = double.tryParse(value) ?? 1000;
                                });
                              },
                              controller: TextEditingController(
                                  text: initialFund.toString()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Devise',
                                style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: currency,
                              dropdownColor: const Color(0xFF16213e),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white10,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: ['USD', 'EUR', 'MGA'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  currency = value!;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2ecc71), Color(0xFF27ae60)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Balance Actuel',
                            style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text(
                          '${currencySymbols[currency]}${getTotalBalance().toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bouton ajouter trade
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  showAddTrade = !showAddTrade;
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un Trade'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Formulaire d'ajout
            if (showAddTrade) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213e),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Montant',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedType,
                            dropdownColor: const Color(0xFF16213e),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Type',
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white10,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'profit', child: Text('Profit')),
                              DropdownMenuItem(value: 'loss', child: Text('Perte')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedType = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedDate = picked;
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white10,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(selectedDate),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: addTrade,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      child: const Text('Enregistrer'),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Statistiques
            const Text(
              'Statistiques Hebdomadaires',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...weeklyStats.entries.toList().reversed.take(4).map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213e),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key,
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '+${currencySymbols[currency]}${entry.value['profit'].toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.green),
                            ),
                            Text(
                              '-${currencySymbols[currency]}${entry.value['loss'].toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                        Text(
                          '${entry.value['net'] >= 0 ? '+' : ''}${currencySymbols[currency]}${entry.value['net'].toStringAsFixed(2)}',
                          style: TextStyle(
                            color: entry.value['net'] >= 0
                                ? Colors.green
                                : Colors.red,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${entry.value['count']} trades',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              );
            }).toList(),

            const SizedBox(height: 24),
            const Text(
              'Statistiques Mensuelles',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...monthlyStats.entries.toList().reversed.take(4).map((entry) {
              DateTime date = DateTime.parse('${entry.key}-01');
              String monthName = DateFormat('MMMM yyyy', 'fr_FR').format(date);
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213e),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(monthName,
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '+${currencySymbols[currency]}${entry.value['profit'].toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.green),
                            ),
                            Text(
                              '-${currencySymbols[currency]}${entry.value['loss'].toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                        Text(
                          '${entry.value['net'] >= 0 ? '+' : ''}${currencySymbols[currency]}${entry.value['net'].toStringAsFixed(2)}',
                          style: TextStyle(
                            color: entry.value['net'] >= 0
                                ? Colors.green
                                : Colors.red,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${entry.value['count']} trades',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              );
            }).toList(),

            const SizedBox(height: 24),
            const Text(
              'Historique des Trades',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...trades.reversed.map((trade) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213e),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('dd/MM/yyyy').format(trade.date),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          if (trade.description.isNotEmpty)
                            Text(
                              trade.description,
                              style: const TextStyle(color: Colors.white54),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${trade.type == 'profit' ? '+' : '-'}${currencySymbols[currency]}${trade.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: trade.type == 'profit' ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => deleteTrade(trade.id),
                    ),
                  ],
                ),
              );
            }).toList(),

            if (trades.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                child: const Center(
                  child: Text(
                    'Aucun trade enregistré.\nAjoutez votre premier trade!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}
