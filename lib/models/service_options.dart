// enum Brands{
//   Shimano,
//   Sram,
//   Tectro,

//   Fox,
//   Rockshox,
//   Ohlins
// } Removed because there isn't any reason to have as an enum not using it ever for object referencing only for string recognition
// which isn't a problem because all the strings you will want to look for will be locally stored inside the Genre object as globalBrand lists

class Service {
  String name;
  List<Genre> genres = [];

  Service(this.name, this.genres);
}

class Genre {
  final String name;
  final List<ServiceType> serviceTypes;
  List<String> applicableBrands;

  Genre(this.name, this.serviceTypes, {this.applicableBrands = const []});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'serviceTypes': serviceTypes.map((st) => st.toMap()).toList(),
      'applicableBrands': applicableBrands,
    };
  }

  factory Genre.fromMap(Map<String, dynamic> map) {
    return Genre(
      map['name'],
      List<ServiceType>.from(
        map['serviceTypes'].map((x) => ServiceType.fromMap(x)),
      ),
      applicableBrands:
          map['applicableBrands'] != null
              ? List<String>.from(map['applicableBrands'])
              : [],
    );
  }

  void updateFields(Genre refGenre) {
    // serviceTypes =
  }
}

class ServiceType {
  final String name;
  final List<String> brands;
  final bool unique;
  int timeEstimate;

  ServiceType(this.name, this.brands, {this.timeEstimate = 0})
    : unique = brands.length == 1;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'brands': brands,
      'unique': unique,
      'timeEstimate': timeEstimate,
    };
  }

  factory ServiceType.fromMap(Map<String, dynamic> map) {
    return ServiceType(
      map['name'],
      map['brands'] == null ? [] : List<String>.from(map['brands']),
      timeEstimate: 0,
    );
  }
}
