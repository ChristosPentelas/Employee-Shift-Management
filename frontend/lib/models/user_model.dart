// Every field is final: a changed profile is a new User (see
// AuthNotifier.updateUser), so whoever watches the session hears about it.
class User{
  final int id;
  final String name;
  final String email;
  final String? phoneNumber; //can be null
  final String role;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    required this.role
  });

  //From JSON to Dart object
  factory User.fromJson(Map<String,dynamic> json) {
    return User(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        phoneNumber: json['phoneNumber'],
        role: json['role']);
  }

  //From Dart object to JSON
  Map<String,dynamic> toJson(){
    return {
      'id' : id,
      'name' : name,
      'email' : email,
      'phoneNumber' : phoneNumber,
      'role' : role,
    };
  }
}