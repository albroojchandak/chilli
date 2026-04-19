import 'dart:math';

class AvatarVault {
  static const List<String> femaleAvatars = [
    'https://i.pinimg.com/736x/20/d5/96/20d5961e97bf5cd9302f24f8ed02f9dd.jpg',
    'https://i.pinimg.com/736x/09/9d/56/099d5648fc30c473a2d01b93abc7852f.jpg',
    'https://i.pinimg.com/736x/74/21/65/7421654187e6c578a242b9489ebd2846.jpg',
    'https://i.pinimg.com/736x/00/43/fe/0043fec2b32e9fc5d3d074211e5b295b.jpg',
    'https://i.pinimg.com/736x/7c/c6/fa/7cc6fa9d0496cf66bb46ea1219a8ef34.jpg',
    'https://i.pinimg.com/736x/ce/70/98/ce709855596e0d769465d6432e123211.jpg',
    'https://i.pinimg.com/736x/70/18/3d/70183dd58c5d02108a91b752c0deb144.jpg',
    'https://i.pinimg.com/736x/0e/3b/5e/0e3b5e6499d0588443275c36b261b89f.jpg',
    'https://i.pinimg.com/736x/5f/95/32/5f9532d978e371c9435bf9e36eb69521.jpg',
    'https://i.pinimg.com/736x/cb/27/99/cb27994dec2da3297c3ff3612d0d113a.jpg',
    'https://i.pinimg.com/736x/1e/4c/d5/1e4cd5ee9b23b5de1621a63ef6b0a079.jpg',
    'https://i.pinimg.com/736x/56/c9/db/56c9db6cb079be4a3d6dce3f659e1f42.jpg',
    'https://i.pinimg.com/736x/17/71/47/177147f021ff3f2bb8cdbb1964141e81.jpg',
    'https://i.pinimg.com/736x/56/3e/dd/563eddb9ad70712e2750c21a71c581b3.jpg',
    'https://i.pinimg.com/736x/d7/09/9e/d7099e50a7fb17776c9fb6ce9e36f88c.jpg',
    'https://i.pinimg.com/736x/c4/8e/60/c48e6019d0a3202f371f8ea7db0894d1.jpg',
    'https://i.pinimg.com/736x/cb/19/d3/cb19d35b0b7d9449e88a13d389f8df4b.jpg',
    'https://i.pinimg.com/736x/8e/d3/29/8ed32941147163547b642c97fc258953.jpg',
    'https://i.pinimg.com/736x/5e/16/58/5e1658cd568eb89c0e70baa1a4e0374e.jpg',
    'https://i.pinimg.com/736x/59/59/f7/5959f7aa8834263ee2f90a772ba95a7d.jpg',
    'https://i.pinimg.com/736x/cd/bc/c0/cdbcc034eac2d6c1b833a38241f465d5.jpg',
    'https://i.pinimg.com/736x/94/7c/94/947c94886264255a4eb4920a69b5e216.jpg',
  ];

  static const List<String> maleAvatars = [
    'https://i.pinimg.com/736x/9a/69/7b/9a697b75243f2e5b26249a186b6a7bba.jpg',
    'https://i.pinimg.com/736x/48/69/fe/4869fe89335aeb7c56ee584d9dcf71bc.jpg',
    'https://i.pinimg.com/736x/de/95/7c/de957cc48278b1232696cac393a7c82f.jpg',
    'https://i.pinimg.com/736x/b6/9b/62/b69b62ca92e54d5a78e22f774776226e.jpg',
    'https://i.pinimg.com/736x/9b/92/c9/9b92c9cbddb0a14b9988cd1146be2ed4.jpg',
    'https://i.pinimg.com/736x/aa/87/6e/aa876e4af34c75ffa37697f77e93ee1c.jpg',
    'https://i.pinimg.com/736x/e2/a9/17/e2a91713579274a0e593dafe93ae349e.jpg',
    'https://i.pinimg.com/736x/06/66/bf/0666bf9cb2f145b5883fb5d4cf14e772.jpg',
    'https://i.pinimg.com/736x/f9/58/74/f9587460511c012e184b2342b4addf33.jpg',
    'https://i.pinimg.com/736x/ef/48/3c/ef483c80c860c3709723ab09bb5de6d9.jpg',
    'https://i.pinimg.com/736x/61/73/63/61736376e4b951553d753dba03afca7d.jpg',
    'https://i.pinimg.com/736x/d3/9c/4a/d39c4a0bf5ffd678d642b07a6e26b4f8.jpg',
    'https://i.pinimg.com/736x/b6/c8/a8/b6c8a8e6115b1e2e57cf7201a4faf1bd.jpg',
    'https://i.pinimg.com/736x/a4/3c/b8/a43cb823c5b0a537eda9fd1c3879981f.jpg',
    'https://i.pinimg.com/736x/a5/9d/b7/a59db7742f98ddde83187ec1a4596054.jpg',
    'https://i.pinimg.com/736x/e6/b0/ca/e6b0cafae602bdddc2f29999474f4513.jpg',
    'https://i.pinimg.com/736x/1a/07/15/1a0715710055287d1cb7054b88fcc33f.jpg',
    'https://i.pinimg.com/736x/78/86/c1/7886c1775799af92aa652347413a4534.jpg',
    'https://i.pinimg.com/736x/5e/18/d8/5e18d8aea4a82866a3aad2d6bb0ed173.jpg',
  ];

  static String resolveRandom(String gender) {
    final random = Random();
    final isFemale = gender.toLowerCase() == 'female';
    final pool = isFemale ? femaleAvatars : maleAvatars;
    return pool[random.nextInt(pool.length)];
  }

  static bool isLegacyAvatar(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return true;
    return avatarUrl.contains('dicebear.com');
  }

  static String resolveOrReplace(String? currentAvatar, String gender) {
    if (isLegacyAvatar(currentAvatar)) {
      return resolveRandom(gender);
    }
    return currentAvatar!;
  }
}
