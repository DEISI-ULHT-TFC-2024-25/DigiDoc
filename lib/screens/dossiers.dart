// DossiersScreen.dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../models/DataBaseHelper.dart';
import '../constants/color_app.dart';
import 'dossier.dart';

class DossiersScreen extends StatefulWidget {
  final CameraDescription camera;

  const DossiersScreen({Key? key, required this.camera}) : super(key: key);

  @override
  _DossiersScreenState createState() => _DossiersScreenState();
}

class _DossiersScreenState extends State<DossiersScreen> {
  TextEditingController dossierController = TextEditingController();
  List<Map<String, dynamic>> dossiers = [];

  @override
  void initState() {
    super.initState();
    loadDossiers();
  }

  void loadDossiers() async {
    List<Map<String, dynamic>> loadedDossiers = await DataBaseHelper.instance.getDossiers();
    setState(() {
      dossiers = loadedDossiers;
    });
  }

  void addDossier(BuildContext context) async {
    String dossierName = dossierController.text.trim();
    if (dossierName.isNotEmpty) {
      bool exists = await DataBaseHelper.instance.isDossierNameExists(dossierName);
      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nome do dossiê já existe!')),
        );
        return;
      }
      int dossierId = await DataBaseHelper.instance.insertDossier(dossierName);
      dossierController.clear();
      loadDossiers();
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O nome do dossiê não pode estar vazio!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: dossiers.isEmpty
          ? const Center(child: Text("Nenhum dossier disponível."))
          : Padding(
        padding: const EdgeInsets.all(10),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.0,
          ),
          itemCount: dossiers.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                final dossier = dossiers[index];
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DossierScreen(
                      dossierId: dossier['dossier_id'] ?? 0,
                      dossierName: dossier['name'] ?? "Sem Nome",
                      camera: widget.camera,
                    ),
                  ),
                );
              },
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.folder, size: 40, color: AppColors.darkerBlue),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    dossiers[index]['name'],
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text("Novo Dossier"),
                content: TextField(
                  controller: dossierController,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Nome do Dossier'),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      dossierController.clear();
                      Navigator.of(context).pop();
                    },
                    child: const Text("Cancelar"),
                  ),
                  TextButton(
                    onPressed: () => addDossier(context),
                    child: const Text("Criar"),
                  ),
                ],
              );
            },
          );
        },
        backgroundColor: AppColors.darkerBlue,
        child: const Icon(Icons.create_new_folder, color: Colors.white),
      ),
    );
  }
}