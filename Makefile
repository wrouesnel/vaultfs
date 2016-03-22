TEST?=$(shell GO15VENDOREXPERIMENT=1 go list -f '{{.ImportPath}}/...' ./... | grep -v /vendor/ | sed "s|$(shell go list -f '{{.ImportPath}}' .)|.|g" | sed "s/\.\/\.\.\./\.\//g")
VET?=$(shell echo ${TEST} | sed "s/\.\.\.//g" | sed "s/\.\/ //g")
VETARGS?=-asmdecl -atomic -bool -buildtags -copylocks -methods -nilfunc -printf -rangeloops -shift -structtags -unsafeptr

all: test vaultfs
	GO15VENDOREXPERIMENT=1 go install $(TEST) -timeout=30s -parallel=4

vaultfs: fmtcheck generate
	GO15VENDOREXPERIMENT=1 go build $(TEST)

install: fmtcheck generate
	GO15VENDOREXPERIMENT=1 go install $(TEST)

# test runs the unit tests and vets the code
test: fmtcheck vet lint
	@echo "==> Testing"
	GO15VENDOREXPERIMENT=1 go test $(TEST) $(TESTARGS) -timeout=30s -parallel=4

# testrace runs the race checker
testrace: fmtcheck generate
	GO15VENDOREXPERIMENT=1 go test -race $(TEST) $(TESTARGS)

cover:
	@go tool cover 2>/dev/null; if [ $$? -eq 3 ]; then \
		go get -u golang.org/x/tools/cmd/cover; \
	fi
	GO15VENDOREXPERIMENT=1 go test $(TEST) -coverprofile=coverage.out
	GO15VENDOREXPERIMENT=1 go tool cover -html=coverage.out
	rm coverage.out

# vet runs the Go source code static analysis tool `vet` to find
# any common errors.
vet:
	@echo "==> Cheking that code complies with go vet requirements..."
	@go tool vet 2>/dev/null ; if [ $$? -eq 3 ]; then \
		go get golang.org/x/tools/cmd/vet; \
	fi
	@GO15VENDOREXPERIMENT=1 go tool vet $(VETARGS) $(VET) ; if [ $$? -eq 1 ]; then \
		echo ""; \
		echo "Vet found suspicious constructs. Please check the reported constructs"; \
		echo "and fix them if necessary before submitting the code for review."; \
		exit 1; \
	fi

lint:
	@golint 2>/dev/null; if [ $$? -eq 127 ]; then \
		go get github.com/golang/lint/golint; \
	fi
	@GO15VENDOREXPERIMENT=1 sh -c "'$(CURDIR)/scripts/golint.sh' ${VET}"; if [ $$? -eq 1 ]; then \
		echo ""; \
		echo "lint found errors in the code. Please check the errors listed above"; \
		echo "and fix them if necessary before submitting the code for review."; \
		exit 1; \
	fi

fmt:
	gofmt -w .

fmtcheck:
	@sh -c "'$(CURDIR)/scripts/gofmtcheck.sh'"

.PHONY: all generate test updatedeps vet fmt fmtcheck