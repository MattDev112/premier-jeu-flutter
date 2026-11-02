import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MonJeu());
}

class MonJeu extends StatelessWidget {
  const MonJeu({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AccueilPage(),
    );
  }
}

class JeuPage extends StatefulWidget {
  const JeuPage({super.key});

  @override
  State<JeuPage> createState() => _JeuPageState();
}

class _JeuPageState extends State<JeuPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController controleur = TextEditingController();

  String niveau = "Facile";
  int maxNombre = 50;
  int viesMax = 10;
  int vies = 10;

  int nombreSecret = Random().nextInt(50) + 1;
  int essais = 0;
  bool partieFinie = false;
  bool victoire = false;
  String message = "Choisis un niveau et devine !";

  late AnimationController pulsation;

  // NOUVEAU : le lecteur de son et les deux sons
  final AudioPlayer lecteur = AudioPlayer();
  late final Uint8List sonVictoire =
  creerSon([523.25, 659.25, 783.99, 1046.50], 0.15);
  late final Uint8List sonDefaite =
  creerSon([392.0, 329.63, 261.63, 196.0], 0.22);

  // NOUVEAU : fabrique un son à partir d'une liste de notes (fréquences)
  Uint8List creerSon(List<double> notes, double dureeNote) {
    const int taux = 44100;
    final List<int> donnees = [];

    for (final frequence in notes) {
      final int nb = (taux * dureeNote).toInt();
      for (int i = 0; i < nb; i++) {
        double fondu = 1 - i / nb; // le son s'éteint doucement
        double valeur = sin(2 * pi * frequence * i / taux) * 0.5 * fondu;
        int echantillon = (valeur * 32767).toInt();
        donnees.add(echantillon & 0xFF);
        donnees.add((echantillon >> 8) & 0xFF);
      }
    }

    // L'en-tête d'un fichier WAV (la "carte d'identité" du son)
    final int taille = donnees.length;
    final ByteData entete = ByteData(44);
    void ecrireTexte(int position, String texte) {
      for (int i = 0; i < texte.length; i++) {
        entete.setUint8(position + i, texte.codeUnitAt(i));
      }
    }

    ecrireTexte(0, 'RIFF');
    entete.setUint32(4, 36 + taille, Endian.little);
    ecrireTexte(8, 'WAVE');
    ecrireTexte(12, 'fmt ');
    entete.setUint32(16, 16, Endian.little);
    entete.setUint16(20, 1, Endian.little);
    entete.setUint16(22, 1, Endian.little);
    entete.setUint32(24, taux, Endian.little);
    entete.setUint32(28, taux * 2, Endian.little);
    entete.setUint16(32, 2, Endian.little);
    entete.setUint16(34, 16, Endian.little);
    ecrireTexte(36, 'data');
    entete.setUint32(40, taille, Endian.little);

    return Uint8List.fromList([...entete.buffer.asUint8List(), ...donnees]);
  }

  @override
  void initState() {
    super.initState();
    pulsation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    pulsation.dispose();
    lecteur.dispose();
    controleur.dispose();
    super.dispose();
  }

  void changerNiveau(String nouveauNiveau) {
    setState(() {
      niveau = nouveauNiveau;
      if (niveau == "Facile") {
        maxNombre = 50;
        viesMax = 10;
      } else if (niveau == "Moyen") {
        maxNombre = 100;
        viesMax = 7;
      } else {
        maxNombre = 200;
        viesMax = 5;
      }
      recommencerPartie();
    });
  }

  void recommencerPartie() {
    nombreSecret = Random().nextInt(maxNombre) + 1;
    essais = 0;
    vies = viesMax;
    partieFinie = false;
    victoire = false;
    message = "Devine un nombre entre 1 et $maxNombre !";
    controleur.clear();
  }

  void verifier() {
    if (partieFinie) return;

    int? nombre = int.tryParse(controleur.text);

    if (nombre == null || nombre < 1 || nombre > maxNombre) {
      setState(() {
        message = "Entre un nombre entre 1 et $maxNombre !";
      });
      return;
    }

    setState(() {
      essais++;

      if (nombre == nombreSecret) {
        message = "🎉 BRAVO ! Trouvé en $essais essais !";
        partieFinie = true;
        victoire = true;
        lecteur.play(BytesSource(sonVictoire)); // 🔊 son de victoire
      } else {
        vies--;
        if (vies == 0) {
          message = "💀 Perdu ! C'était $nombreSecret";
          partieFinie = true;
          lecteur.play(BytesSource(sonDefaite)); // 🔊 son de défaite
        } else if (nombre < nombreSecret) {
          message = "📈 C'est plus grand !";
        } else {
          message = "📉 C'est plus petit !";
        }
      }
      controleur.clear();
    });
  }

  void recommencer() {
    setState(() {
      recommencerPartie();
    });
  }

  @override
  Widget build(BuildContext context) {
    Color couleurNeon = Colors.cyanAccent;
    if (partieFinie && victoire) {
      couleurNeon = Colors.greenAccent;
    } else if (partieFinie) {
      couleurNeon = Colors.redAccent;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text("🎮 BIENVENUE"),
        backgroundColor: const Color(0xFF111A33),
        foregroundColor: Colors.cyanAccent,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: pulsation,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: couleurNeon
                              .withOpacity(0.2 + 0.5 * pulsation.value),
                          blurRadius: 20 + 30 * pulsation.value,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: Icon(
                  Icons.sports_esports,
                  color: couleurNeon,
                  size: 90,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ["Facile", "Moyen", "Difficile"].map((n) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(n),
                      selected: niveau == n,
                      selectedColor: Colors.cyanAccent,
                      onSelected: (_) => changerNiveau(n),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 15),
              Text(
                "❤️ Vies : $vies / $viesMax",
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 20),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF111A33),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: couleurNeon, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: couleurNeon.withOpacity(0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (enfant, animation) {
                    return ScaleTransition(scale: animation, child: enfant);
                  },
                  child: Text(
                    message,
                    key: ValueKey("$message-$essais"),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: couleurNeon,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              TextField(
                controller: controleur,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 25),
                decoration: InputDecoration(
                  hintText: "Ton nombre...",
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF111A33),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.cyanAccent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide:
                    const BorderSide(color: Colors.pinkAccent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: partieFinie ? null : verifier,
                child: const Text(
                  "VÉRIFIER",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                "Nombre d'essais : $essais",
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 25),
              TextButton(
                onPressed: recommencer,
                child: const Text(
                  "Recommencer 🔄",
                  style: TextStyle(color: Colors.orange, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key});

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage>
    with SingleTickerProviderStateMixin {

  late AnimationController animation;

  @override
  void initState() {
    super.initState();

    animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  void jouer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const JeuPage(),
      ),
    );
  }

  void afficherRegles() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111A33),
        title: const Text(
          "📖 COMMENT JOUER ?",
          style: TextStyle(color: Colors.cyanAccent),
        ),
        content: const Text(
          "1. Choisis ton niveau.\n\n"
              "2. Devine le nombre secret.\n\n"
              "3. Utilise les indices pour trouver "
              "le bon nombre.\n\n"
              "4. Attention à tes vies !\n\n"
              "5. Trouve le nombre le plus rapidement possible "
              "pour obtenir un meilleur score.",
          style: TextStyle(
            color: Colors.white,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "COMPRIS !",
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D1B),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),

            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                const SizedBox(height: 25),

                // LOGO ANIMÉ
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF111A33),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyanAccent.withOpacity(
                              0.2 + animation.value * 0.5,
                            ),
                            blurRadius: 25 + animation.value * 30,
                            spreadRadius: 3,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.yellow,
                          width: 2,
                        ),
                      ),
                      child: child,
                    );
                  },
                  child: const Icon(
                    Icons.psychology,
                    color: Colors.yellowAccent,
                    size: 85,
                  ),
                ),

                const SizedBox(height: 35),

                // NOM DU JEU
                const Text(
                  "DEVINES LE",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),

                const Text(
                  "NOMBRE",
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                    shadows: [
                      Shadow(
                        color: Colors.cyanAccent,
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  "TESTE TON INTELLIGENCE",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    letterSpacing: 3,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  "Un nombre secret t'attend...\n"
                      "Seras-tu capable de le découvrir ?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 45),

                // CARTE DES INFORMATIONS
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111A33),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.cyanAccent.withOpacity(0.4),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: Colors.amber,
                        size: 35,
                      ),
                      SizedBox(height: 10),
                      Text(
                        "TON PROCHAIN DÉFI",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "3 niveaux • Des défis • Des records",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 35),

                // BOUTON JOUER
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: jouer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: const Color(0xFF080D1B),
                      elevation: 15,
                      shadowColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow, size: 30),
                        SizedBox(width: 10),
                        Text(
                          "JOUER MAINTENANT",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // BOUTON REGLES
                TextButton.icon(
                  onPressed: afficherRegles,
                  icon: const Icon(
                    Icons.menu_book,
                    color: Colors.white70,
                  ),
                  label: const Text(
                    "COMMENT JOUER ?",
                    style: TextStyle(
                      color: Colors.white70,
                      letterSpacing: 1,
                    ),
                  ),
                ),

                const SizedBox(height: 35),

                const Text(
                  "DEVELOPPEE PAR J.MATTHIAS",
                  style: TextStyle(
                    color: Colors.white30,
                    fontSize: 11,
                    letterSpacing: 3,
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}