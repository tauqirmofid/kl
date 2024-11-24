import 'package:flutter/material.dart';
import 'sudoku_board.dart';

void main() {
  runApp(const SudokuGame());
}

class SudokuGame extends StatelessWidget {
  const SudokuGame({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku Game',
      theme: ThemeData.dark(),
      home: const SudokuBoard(),
      debugShowCheckedModeBanner: false,
    );
  }
}
