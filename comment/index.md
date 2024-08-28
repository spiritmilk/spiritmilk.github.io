---
title: 留言板


---

<head>
  <!-- ... -->
  <script src="https://unpkg.com/@waline/client@v2/dist/waline.js"></script>
  <link
    rel="stylesheet"
    href="https://unpkg.com/@waline/client@v2/dist/waline.css"
  />
  <!-- ... -->
</head>
<body>
  <!-- ... -->
  <div id="waline"></div>
  <script>
    Waline.init({
      el: '#waline',
      serverURL: 'https://message-board-mnqj7pg0c-dkhonker.vercel.app/',
    });
  </script>
</body>


