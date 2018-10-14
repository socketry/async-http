const inputStream = new ReadableStream({
	start(controller) {
		interval = setInterval(() => {
			let string = "Hello World!";

			// Add the string to the stream
			controller.enqueue(string);

			// show it on the screen
			let listItem = document.createElement('li');
			listItem.textContent = string;
			sent.appendChild(listItem);
		}, 10000);

		stopButton.addEventListener('click', function() {
			clearInterval(interval);
			controller.close();
		})
	},
	pull(controller) {
		// We don't really need a pull in this example
	},
	cancel() {
		// This is called if the reader cancels,
		// so we should stop generating strings
		clearInterval(interval);
	}
});

fetch("/echo", {method: 'POST', body: inputStream})
	.then(response => {
		const reader = response.body.getReader();
		const decoder = new TextDecoder("utf-8");
		
		function push() {
			reader.read().then(({done, value}) => {
				console.log("done:", done, "value:", value);
				const string = decoder.decode(value);
				
				// show it on the screen
				let listItem = document.createElement('li');
				
				if (done)
					listItem.textContent = "<EOF>"
				else
					listItem.textContent = string;
				
				received.appendChild(listItem);
				
				if (done) return;
				else push();
			});
		};
		
		push();
	});
