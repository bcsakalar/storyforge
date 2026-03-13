// StoryForge Real-time Client
(function () {
  if (typeof io === 'undefined') return;

  var socket = io({ withCredentials: true });
  window.sfSocket = socket;

  socket.on('connect', function () {
    // Auto-join co-op room if on co-op session page
    var coopEl = document.getElementById('coopSessionId');
    if (coopEl) socket.emit('coop:join', parseInt(coopEl.value));

    // Auto-join chat room if on chat page
    var chatPartner = document.getElementById('chatPartnerId');
    if (chatPartner) socket.emit('chat:join', parseInt(chatPartner.value));
  });

  // ===== Notification badge =====
  socket.on('notification:new', function (notif) {
    var badge = document.getElementById('notifBadge');
    if (badge) {
      var count = parseInt(badge.textContent || '0') + 1;
      badge.textContent = count;
      badge.style.display = 'inline-flex';
    }
    // Show toast
    showToast((notif.title || 'Bildirim') + ': ' + (notif.body || ''));
  });

  // ===== Message notification (when NOT on chat page) =====
  socket.on('message:notification', function (data) {
    var badge = document.getElementById('msgBadge');
    if (badge) {
      var count = parseInt(badge.textContent || '0') + 1;
      badge.textContent = count;
      badge.style.display = 'inline-flex';
    }
    // Show toast if not on chat page with that user
    var chatPartner = document.getElementById('chatPartnerId');
    if (!chatPartner || parseInt(chatPartner.value) !== data.senderId) {
      showToast('@' + data.senderUsername + ': ' + data.content);
    }
  });

  // ===== Real-time chat message =====
  socket.on('message:new', function (msg) {
    var chatContainer = document.getElementById('chatMessages');
    if (!chatContainer) return;

    var currentUserId = parseInt(document.getElementById('currentUserId').value);
    var isSent = msg.senderId === currentUserId;
    var div = document.createElement('div');
    div.className = 'sf-message ' + (isSent ? 'sent' : 'received');

    var escapedContent = msg.content.replace(/</g, '&lt;').replace(/>/g, '&gt;');
    var time = new Date(msg.createdAt).toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' });
    div.innerHTML = '<p>' + escapedContent + '</p><span class="sf-msg-time">' + time + '</span>';
    chatContainer.appendChild(div);
    chatContainer.scrollTop = chatContainer.scrollHeight;
  });

  // ===== Friend request =====
  socket.on('friend:request', function (data) {
    showToast('@' + data.sender.username + ' sana arkadaşlık isteği gönderdi!');
    var badge = document.getElementById('notifBadge');
    if (badge) {
      var count = parseInt(badge.textContent || '0') + 1;
      badge.textContent = count;
      badge.style.display = 'inline-flex';
    }
    // If on friends page, reload
    if (window.location.pathname === '/friends') {
      window.location.reload();
    }
  });

  // ===== Friend accepted =====
  socket.on('friend:accepted', function (data) {
    showToast('@' + data.friend.username + ' arkadaşlık isteğini kabul etti!');
    if (window.location.pathname === '/friends') {
      window.location.reload();
    }
  });

  // ===== Co-op invite =====
  socket.on('coop:invite', function (data) {
    showToast('@' + data.host.username + ' seni co-op hikayeye davet etti!');
    if (window.location.pathname === '/coop') {
      window.location.reload();
    }
  });

  // ===== Co-op new chapter =====
  socket.on('coop:newChapter', function (data) {
    if (window.location.pathname.startsWith('/coop/')) {
      window.location.reload();
    }
  });

  // ===== Social: like update =====
  socket.on('social:like', function (data) {
    // Update like count on shared story detail page
    var likeBtn = document.querySelector('.sf-social-actions form button');
    if (likeBtn && window.location.pathname.startsWith('/shared/')) {
      var pathId = window.location.pathname.split('/shared/')[1];
      if (parseInt(pathId) === data.sharedStoryId) {
        likeBtn.innerHTML = (data.likeCount > 0 ? '❤️' : '🤍') + ' ' + data.likeCount;
      }
    }
    // Update like counts on explore page
    if (window.location.pathname === '/explore') {
      window.location.reload();
    }
  });

  // ===== Social: comment update =====
  socket.on('social:comment', function (data) {
    if (window.location.pathname.startsWith('/shared/')) {
      var pathId = window.location.pathname.split('/shared/')[1];
      if (parseInt(pathId) === data.sharedStoryId) {
        // Reload to show new comment
        window.location.reload();
      }
    }
    // Update comment counts on explore page
    if (window.location.pathname === '/explore') {
      window.location.reload();
    }
  });

  // ===== Toast notification helper =====
  function showToast(message) {
    var container = document.getElementById('sf-toast-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'sf-toast-container';
      document.body.appendChild(container);
    }
    var toast = document.createElement('div');
    toast.className = 'sf-toast';
    toast.textContent = message;
    container.appendChild(toast);
    setTimeout(function () { toast.classList.add('show'); }, 10);
    setTimeout(function () {
      toast.classList.remove('show');
      setTimeout(function () { toast.remove(); }, 300);
    }, 4000);
  }
})();
