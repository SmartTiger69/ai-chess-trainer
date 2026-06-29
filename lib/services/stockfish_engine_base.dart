abstract class StockfishEngine {
  Stream<String> get stdout;

  Future<void> initialize();

  void send(String command);

  void dispose();
}
