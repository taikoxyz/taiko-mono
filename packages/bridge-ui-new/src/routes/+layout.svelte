<script>
	import '../app.css';
	import Header from '../components/Header';
	import Footer from '../components/Footer';
</script>

<div>
	<Header />
	<main>
		<slot />
	</main>
	<Footer />
</div>
