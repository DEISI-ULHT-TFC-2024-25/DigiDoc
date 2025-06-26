import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/data_base_helper.dart';
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

  void deleteDossier(BuildContext context, int dossierId, String dossierName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkCardBackground
              : AppColors.cardBackground,
          title: Text(
            'Apagar Dossiê',
            style: GoogleFonts.poppins(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextPrimary
                  : AppColors.textPrimary,
            ),
          ),
          content: Text(
            'Tem certeza que deseja apagar o dossiê "$dossierName"?',
            style: GoogleFonts.poppins(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkPrimaryGradientStart
                      : AppColors.primaryGradientStart,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Apagar',
                style: GoogleFonts.poppins(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkPrimaryGradientStart
                      : AppColors.primaryGradientStart,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await DataBaseHelper.instance.deleteDossier(dossierId);
      loadDossiers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dossiê "$dossierName" apagado com sucesso!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkBackground
            : AppColors.background,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: dossiers.isEmpty
                ? Center(
              child: Text(
                "Nenhum dossier disponível.",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.textSecondary,
                ),
              ),
            )
                : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0,
              ),
              itemCount: dossiers.length,
              itemBuilder: (context, index) {
                final dossier = dossiers[index];
                return GestureDetector(
                  onTap: () {
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
                  onLongPress: () {
                    deleteDossier(
                      context,
                      dossier['dossier_id'] ?? 0,
                      dossier['name'] ?? "Sem Nome",
                    );
                  },
                  child: Card(
                    elevation: 2,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkCardBackground
                        : AppColors.cardBackground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder,
                          size: 40,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkTextPrimary
                              : AppColors.primaryGradientStart,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dossiers[index]['name'],
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkCardBackground
                    : AppColors.cardBackground,
                title: Text(
                  "Novo Dossier",
                  style: GoogleFonts.poppins(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                content: TextField(
                  controller: dossierController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Nome do Dossier',
                    hintStyle: GoogleFonts.poppins(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkCardBackground.withOpacity(0.8)
                        : AppColors.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: GoogleFonts.poppins(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      dossierController.clear();
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      "Cancelar",
                      style: GoogleFonts.poppins(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkPrimaryGradientStart
                            : AppColors.primaryGradientStart,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => addDossier(context),
                    child: Text(
                      "Criar",
                      style: GoogleFonts.poppins(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkPrimaryGradientStart
                            : AppColors.primaryGradientStart,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkPrimaryGradientStart
            : AppColors.primaryGradientStart,
        child: const Icon(Icons.create_new_folder, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}