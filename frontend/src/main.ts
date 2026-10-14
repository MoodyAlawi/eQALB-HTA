import { createApp } from 'vue'
import App from './App.vue'
import './styles.css'
// The landing page's own stylesheet, loaded after the app's so its scoped rules
// win where the two meet. See the file header for how it stays scoped.
import './landing.css'
// The blog's stylesheet, loaded last: it reads the landing page's tokens and
// stays scoped under its own root class, so it neither reaches the landing page
// nor the app. See the file header.
import './blog.css'

createApp(App).mount('#app')
