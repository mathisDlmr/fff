package main

import (
	"fmt"
	"html/template"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
)

type Context struct {
	LogFiles []string
	Style    string
}

func logDir() string {
	if dir, ok := os.LookupEnv("LOG_PATH"); ok {
		return dir + "/log/"
	} else {
		return "/pgdata/pg14/log/"
	}
}

func homePage(w http.ResponseWriter, r *http.Request) {
	var context Context

	c, err := r.Cookie("style")
	if err != nil {
		if err == http.ErrNoCookie {
			http.SetCookie(w, &http.Cookie{
				Name:  "style",
				Value: "xp",
			})
			context.Style = "xp"
		} else {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
	} else {
		context.Style = c.Value
	}

	items, _ := os.ReadDir(logDir())
	for _, item := range items {
		context.LogFiles = append(context.LogFiles, item.Name())
	}

	tmpl, err := template.New("output").ParseFiles("index.html")
	if err != nil {
		log.Println(fmt.Sprintf("error: %s", err))
		return
	}

	err = tmpl.ExecuteTemplate(w, "index.html", context)
	if err != nil {
		log.Println(fmt.Sprintf("error: %s", err))
		return
	}
}

func keys[T comparable, U any](mp map[T]U) []T {
	keys := make([]T, len(mp))

	i := 0
	for k := range mp {
		keys[i] = k
		i++
	}
	return keys
}

func Map[T, U any](ts []T, f func(T) U) []U {
	us := make([]U, len(ts))
	for i := range ts {
		us[i] = f(ts[i])
	}
	return us
}

func addLog(n string) string {
	return logDir() + n
}

func genBadger(w http.ResponseWriter, r *http.Request) {
	f, err := os.CreateTemp("", "out-*.html")
	if err != nil {
		log.Print(err)
		return
	}
	f.Close()
	defer os.Remove(f.Name())

	log.Println("temp file: ", f.Name())
	cmd := exec.Command("pgbadger",
		append([]string{"-o", f.Name(), "--prefix", "%m [%p] %r %a %u@%d"}, Map(keys(r.URL.Query()), addLog)...)...,
	)

	err = cmd.Run()
	if err != nil {
		log.Println(fmt.Sprintf("error: %s", err))
		return
	}

	file, err := os.Open(f.Name())
	if err != nil {
		log.Println(fmt.Sprintf("error: %s", err))
		return
	}
	defer file.Close()
	_, err = io.Copy(w, file)
	if err != nil {
		log.Println(fmt.Sprintf("error: %s", err))
		return
	}

	log.Println("Generated")
}

func main() {
	log.Print("starting genBadger")
	http.HandleFunc("/", homePage)
	http.HandleFunc("/generate", genBadger)

	fs := http.FileServer(http.Dir("public"))
	http.Handle("/public/", http.StripPrefix("/public/", fs))

	log.Fatal(http.ListenAndServe(":8000", nil))
}
