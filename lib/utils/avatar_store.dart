import 'dart:math';

class AvatarVault {
  static const List<String> femaleAvatars = [
    'https://i.pinimg.com/736x/4c/22/82/4c2282f1d087e65e15331fada7b77685.jpg',
    'https://i.pinimg.com/736x/c3/ca/5c/c3ca5c2e424ee5055eee2801b81a4568.jpg',
    'https://i.pinimg.com/736x/10/0f/14/100f14de660d707d3c53abd9bee388de.jpg',
    'https://i.pinimg.com/736x/90/f9/a1/90f9a1332a5638055d8f271ff559e5a8.jpg',
    'https://i.pinimg.com/736x/d7/14/0e/d7140e9239d0a4d37545042cd77a0725.jpg',
    'https://i.pinimg.com/736x/07/bc/79/07bc798fef120b51124151e8384aa89c.jpg',
    'https://i.pinimg.com/736x/cb/9b/fb/cb9bfbe699771f129ff124c67fea62cb.jpg',
    'https://i.pinimg.com/736x/14/6d/f4/146df4625ebb8192b37a77c270b48e42.jpg',
    'https://i.pinimg.com/736x/a6/df/61/a6df61d684eac010332639c70b9986a1.jpg',
    'https://i.pinimg.com/736x/07/ef/2e/07ef2e9b1c63f45bc5fa262d67f51768.jpg',
    'https://i.pinimg.com/736x/7b/d1/a8/7bd1a8dabac1d087e49261bc056d84d1.jpg',
    'https://i.pinimg.com/736x/b5/f2/0a/b5f20a669ecc21a497341476412736ca.jpg',
    'https://i.pinimg.com/736x/85/c1/b1/85c1b1b9cd875fb43d813257a370ec08.jpg',
    'https://i.pinimg.com/736x/a6/25/2e/a6252e6cd95996b327c8f248e3ff06d5.jpg',
    'https://i.pinimg.com/736x/d3/61/68/d361689c467a3d34502e74a2655d7a83.jpg',
    'https://i.pinimg.com/736x/c3/c1/26/c3c126dd7019492d9c4289ac903594ff.jpg',
    'https://i.pinimg.com/736x/44/40/56/444056d88150a85058a778632affc9b6.jpg',
    'https://i.pinimg.com/736x/20/f9/cc/20f9cc8692f2861c1ec7de9dff1ed745.jpg',
    'https://i.pinimg.com/736x/c8/d6/4c/c8d64c1670715f171e309b08a0e85db1.jpg',
    'https://i.pinimg.com/736x/04/27/c4/0427c484d6e017d5eee2057b6fa8673a.jpg',
    'https://i.pinimg.com/736x/ae/9b/26/ae9b26de1ace247334794125cc3d3d63.jpg',
    'https://i.pinimg.com/736x/c2/32/ba/c232ba643858646c4f300653e65b7ef4.jpg',
    'https://i.pinimg.com/736x/b9/8f/b0/b98fb0fb0a90c0cd872dd041406c6139.jpg',
    'https://i.pinimg.com/736x/e9/1f/72/e91f72ee4167e833518e468901da1d28.jpg',
    'https://i.pinimg.com/736x/ed/00/5a/ed005a9874861b5735e73d7d7b5df0e1.jpg',
    'https://i.pinimg.com/736x/87/75/ca/8775caaa8bb9b34682f27e1f7ac719d4.jpg',
    'https://i.pinimg.com/736x/48/7f/98/487f98a1379c17fe5515c17e27e5d17a.jpg',
    'https://i.pinimg.com/736x/95/d8/85/95d8858f31666a5c6bb76b2ebacae7e6.jpg',
  ];

  static const List<String> maleAvatars = [
    'https://i.pinimg.com/736x/45/e1/ec/45e1ece7ab117d1ce24608a59236cc9c.jpg',
    'https://i.pinimg.com/736x/ee/ad/36/eead36a1298e19e59a85838baef42243.jpg',
    'https://i.pinimg.com/736x/65/55/33/655533d43ce7d61ce86fcbf0f122b24c.jpg',
    'https://i.pinimg.com/736x/4b/38/61/4b3861fcc10c6d31f82263243218aeb0.jpg',
    'https://i.pinimg.com/736x/9e/ad/fd/9eadfdb97052f7767e4bb8bf795cfb3f.jpg',
    'https://i.pinimg.com/736x/8c/d2/43/8cd24392a904dbe5995740f6abe36908.jpg',
    'https://i.pinimg.com/1200x/e4/79/e6/e479e68c8956f86819c576b94e1f2843.jpg',
    'https://i.pinimg.com/736x/be/2e/34/be2e34ae822e0ca4c7ae82459032364e.jpg',
    'https://i.pinimg.com/736x/e9/20/f1/e920f134296233fe36fce2d96749dedf.jpg',
    'https://i.pinimg.com/736x/03/85/80/038580ac6e3e2c5eb719ccf52935c71e.jpg',
    'https://i.pinimg.com/736x/39/d8/0f/39d80f39e55a47d5f1bcb2e69cda9f5e.jpg',
    'https://i.pinimg.com/736x/28/42/78/28427818f1cbee81b3e6f8e6fa4c16bc.jpg',
    'https://i.pinimg.com/736x/ab/d5/bf/abd5bf400a1475b76d8614cf6e815b8b.jpg',
    'https://i.pinimg.com/736x/ef/b4/bb/efb4bb3591c075d97b7f9f961d5688f3.jpg',
    'https://i.pinimg.com/736x/12/0c/65/120c65e2b40465086d3af063731189de.jpg',
    'https://i.pinimg.com/736x/22/0f/95/220f9526d69273015ef759ece9ebc8d6.jpg',
    'https://i.pinimg.com/736x/89/ce/b8/89ceb806ca06e96edda1ef13cb9c5d9d.jpg',
    'https://i.pinimg.com/736x/2c/71/91/2c7191e6a671055000187d2fd11c523b.jpg',
    'https://i.pinimg.com/736x/51/7e/08/517e08e8ec40b2e943c1c7d70fa3d51a.jpg',
    'https://i.pinimg.com/736x/bf/b1/bc/bfb1bc92f0f6cb3dec0b0bae0c68ba09.jpg',
    'https://i.pinimg.com/736x/45/02/29/4502298d108880fe96b1c416f0b6209e.jpg',
    'https://i.pinimg.com/736x/09/65/b7/0965b7dd3aaf81f85ea692aaf529efee.jpg',
    'https://i.pinimg.com/736x/f6/39/73/f63973990915a9594ab1451d5013abf9.jpg',
    'https://i.pinimg.com/1200x/13/9a/8e/139a8ef41d3c937eb1044c291823cb3c.jpg',
    'https://i.pinimg.com/1200x/e0/eb/e5/e0ebe54a5d0e6467b92ab4325858aa7d.jpg',
    'https://i.pinimg.com/736x/9c/29/a3/9c29a39b42262114feae9d8098733a55.jpg',
    'https://i.pinimg.com/736x/4f/a5/c0/4fa5c04ba24dd667704038e276a916c5.jpg',
    'https://i.pinimg.com/736x/13/46/27/134627c18dce0c7ed330253bbde44f07.jpg',
    'https://i.pinimg.com/736x/75/9b/f8/759bf82dda36e911242fb6f5a6a9534c.jpg',
    'https://i.pinimg.com/736x/ac/6e/8f/ac6e8f1f579e77030196932df4af6e14.jpg',
    'https://i.pinimg.com/736x/af/ef/eb/afefeb59f617fa7f8305c41af3cc5d45.jpg',
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
