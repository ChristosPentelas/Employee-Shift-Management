class User{
  final int id;
  String name;
  String email;
  String? phoneNumber; //can be null
  String password;
  final String role;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    required this.password,
    required this.role
  });

  //From JSON to Dart object
  factory User.fromJson(Map<String,dynamic> json) {
    return User(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        phoneNumber: json['phoneNumber'],
        password: json['password'],
        role: json['role']);
  }

  //From Dart object to JSON
  Map<String,dynamic> toJson(){
    return {
      'id' : id,
      'name' : name,
      'email' : email,
      'phoneNumber' : phoneNumber,
      'password' : password,
      'role' : role,
    };
  }
}