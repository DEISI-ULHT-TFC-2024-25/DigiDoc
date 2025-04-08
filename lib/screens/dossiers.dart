import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../DataBaseHelper.dart';
import '../main.dart';
import 'dossier.dart';



class DossiersScreen extends StatefulWidget {
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
    List<Map<String, dynamic>> loadedDossiers =
    await DataBaseHelper().getDossiers();
    setState(() {
      dossiers = loadedDossiers;
    });
  }

  void addDossier(BuildContext context) async {
    String dossierName = dossierController.text;
    if (dossierName.isNotEmpty) {
      await DataBaseHelper().createDossier(dossierName);
      dossierController.clear();
      loadDossiers();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Lista de Dossiers")),
      body: dossiers.isEmpty
          ? Center(child: Text("Nenhum dossier disponível."))
          : Padding(
        padding: EdgeInsets.all(10),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                      dossierId: dossier['id'] ?? 0,
                      dossierName: dossier['name'] ?? "Sem Nome",
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
                    child: Icon(Icons.folder,
                        size: 40, color: AppColors.mainSolidDarkerColor),
                  ),
                  SizedBox(height: 5),
                  Text(dossiers[index]['name'],
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
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
                title: Text("Novo Dossier"),
                content: TextField(
                  controller: dossierController,
                  autofocus: true,
                  decoration: InputDecoration(hintText: 'Nome do Dossier'),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      dossierController.clear();
                      Navigator.of(context).pop();
                    },
                    child: Text("Cancelar"),
                  ),
                  TextButton(
                    onPressed: () => addDossier(context),
                    child: Text("Criar"),
                  ),
                ],
              );
            },
          );
        },
        backgroundColor: AppColors.mainSolidDarkerColor,
        child: Icon(Icons.create_new_folder, color: Colors.white),
      ),
    );
  }
}