import 'package:flutter/material.dart';
import 'package:speech_to_tex/speech_to_text.dart';
import 'package:speech_to_tex/vosk.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Home"),),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(onPressed: (){
              Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                return SpeechSampleApp();
              },));
            }, child: const Text("Google")),
            const SizedBox(height: 12,),
            ElevatedButton(onPressed: (){
              Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                return VoskView();
              },));
            }, child: const Text("Vosk")),
          ],
        ),
      ),
    );
  }
}
