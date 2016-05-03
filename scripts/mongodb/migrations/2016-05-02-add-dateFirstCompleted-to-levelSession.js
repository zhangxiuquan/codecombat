var sessions = db.level.sessions.find();
sessions.forEach(function (session) {
  if (session.state.complete && !session.dateFirstCompleted) {
    print('session', session._id, 'updated!');
    db.level.sessions.update(
      { _id: session._id },
      { $set: { dateFirstCompleted: session.changed.toISOString() } }
    );
  }
});
