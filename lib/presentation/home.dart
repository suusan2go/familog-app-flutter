import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:familog/domain/diary.dart';
import 'package:familog/domain/diary_entry.dart';
import 'package:familog/domain/diary_entry_repository.dart';
import 'package:familog/presentation/diary_entry_form.dart';
import 'package:familog/presentation/my_drawer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:familog/presentation/diary_entry_detail.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

typedef increment = void Function();

final googleSignIn = new GoogleSignIn();
final auth = FirebaseAuth.instance;
final analytics = new FirebaseAnalytics();

class Home extends StatefulWidget {
  Home({Key key, this.title}) : super(key: key);

  final String title;
  @override
  State<StatefulWidget> createState() {
    return new _HomeState();
  }
}

class _HomeState extends State<Home> {
  FirebaseUser _user;
  Diary _currentDiary;
  DiaryEntryRepository repository;
  List<DiaryEntry> _entries;
  ScrollController _controller = new ScrollController();

  @override
  void initState() {
    super.initState();
    repository =new DiaryEntryRepository();
    _controller.addListener(this._loadMoreEntries);
    var entries = repository.findAll();
    setState(() {
      this._entries = entries;
    });
  }

  void _loadMoreEntries() {
    if(_controller.position.atEdge && _controller.position.pixels == _controller.position.maxScrollExtent) {
      setState(() {
        this._entries.addAll(repository.findAll());
      });
    }
  }

  Future<Null> _onRefresh() {
    var completer = new Completer<FirebaseUser>();
    new Timer(const Duration(seconds: 1), () { completer.complete(null); });
    return completer.future.then((_) {
      setState(() {
        this._entries.insertAll(0, repository.findAll());
      });
    });
  }

  Future<Null> _logIn() async {
    _ensureLoggedIn().then((user) async {
      var diaries = await Firestore.instance.collection('diaries').where("subscribers.${user.uid}", isEqualTo: true).getDocuments();
      if(diaries.documents.length == 0) {
        Firestore.instance.collection('diaries').document()
            .setData({
          'title': '${user.displayName}の日記',
          'subscribers': { user.uid: true}
        });
      }
      var diaryRef = await Firestore.instance.collection('diaries').where("subscribers.${user.uid}", isEqualTo: true).getDocuments();
      var diaryDocument = diaryRef.documents.first;
      setState((){
        this._user = user;
        this._currentDiary = new Diary(diaryDocument.documentID, diaryDocument["title"]);
      });
    });
  }

  Future<FirebaseUser> _ensureLoggedIn() async {
    GoogleSignInAccount user = googleSignIn.currentUser;
    if (user == null)
      user = await googleSignIn.signInSilently();
    if (user == null) {
      await googleSignIn.signIn();
      analytics.logLogin();
    }
    if (await auth.currentUser() == null) {
      GoogleSignInAuthentication credentials = await googleSignIn.currentUser.authentication;
      await auth.signInWithGoogle(
        idToken: credentials.idToken,
        accessToken: credentials.accessToken,
      );
    }
    return await auth.currentUser();
  }

  Widget _buildNotLoggedIn(BuildContext context) {
    return new Center(
      child: new Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          new RaisedButton(onPressed: _logIn, child: new Text("ログイン"))
        ],
      ),
    );
  }

  Widget _itemBuilder(BuildContext context, int index) {
    var entry = this._entries[index];
    return new DiaryEntryItem(entry);
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      drawer: new MyDrawer(user: this._user,),
      appBar: new AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: new Text(widget.title),
      ),
      body:
      _user == null ?  _buildNotLoggedIn(context): new RefreshIndicator(
          onRefresh: _onRefresh,
          child: new Scrollbar(
              child: new ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemBuilder: _itemBuilder,
                itemCount: _entries.length,
                controller: _controller,
              )
          )
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: (){
          Navigator.of(context).push(new MaterialPageRoute(
              builder: (context) => new DiaryEntryForm(currentDiary: this._currentDiary),
              fullscreenDialog: true
          ));
        },
        tooltip: 'Increment',
        child: new Icon(Icons.edit),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class DiaryEntryItem extends StatelessWidget {
  DiaryEntryItem(DiaryEntry diaryEntry): diaryEntry = diaryEntry;

  final DiaryEntry diaryEntry;

  @override
  Widget build(BuildContext context) {
    return new Card(
      child: new InkWell(
        onTap: () {
          Navigator.of(context).push(new MaterialPageRoute(
            builder: (context) => new DiaryEntryDetail("日記ですよ！", 1),
          ));
        },
        child: new Row(
          children: <Widget>[
            new Image.network(diaryEntry.images.first.url, height: 100.0, width: 100.0, fit: BoxFit.cover),
            new Expanded(
                child: new Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    new Container(
                      child: new Text(diaryEntry.title(), softWrap: true, style: new TextStyle(
                          fontWeight: FontWeight.w300,
                          fontSize: 16.0
                      ),),
                      padding: const EdgeInsets.only(left: 10.0, right: 10.0),
                    ),
                    new Container(
                      child: new Text(diaryEntry.body,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                        style: new TextStyle(
                            fontSize: 14.0,
                            color: Colors.black87
                        ),
                      ),
                      padding: const EdgeInsets.only(left: 10.0, right: 10.0),
                    )
                  ],
                )
            )
          ],
        ),
      ),
    );
  }
}
